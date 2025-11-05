#!/usr/bin/env python3
"""
Dashboard server for AWS Glacier vaults management
Runs a local web server with GUI and REST API
"""

import http.server
import socketserver
import json
import subprocess
import os
import glob
from datetime import datetime
from pathlib import Path
import threading
import time
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get('PORT', 8080))

# Determine project root directory
# If run from web/, go up one level
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR) if os.path.basename(SCRIPT_DIR) == 'web' else SCRIPT_DIR

# Project directories
DATA_DIR = os.path.join(ROOT_DIR, "data")
SCRIPTS_DIR = os.path.join(ROOT_DIR, "scripts")
WEB_DIR = os.path.join(ROOT_DIR, "web")

# Running processes
running_processes = {}


def get_vault_status():
    """Retrieve status of all vaults"""
    status = {
        "timestamp": datetime.now().isoformat(),
        "vaults": [],
        "jobs": [],
        "deletion_progress": {},
        "logs": []
    }

    # Read glacier.json
    glacier_file = os.path.join(DATA_DIR, "glacier.json")
    if os.path.exists(glacier_file):
        with open(glacier_file, 'r') as f:
            glacier_data = json.load(f)
            status["vaults"] = glacier_data.get("VaultList", [])

    # Read jobs
    job_files = glob.glob(os.path.join(DATA_DIR, "job_data", "job_*.json"))
    for job_file in job_files:
        try:
            with open(job_file, 'r') as f:
                job_data = json.load(f)
                vault_name = os.path.basename(job_file).replace("job_", "").replace(".json", "")

                # Check job status via AWS CLI
                job_status = check_job_status(vault_name, job_data.get("jobId"))

                status["jobs"].append({
                    "vault": vault_name,
                    "jobId": job_data.get("jobId"),
                    "status": job_status
                })
        except Exception as e:
            print(f"Error reading job {job_file}: {e}")

    # Read deletion progress
    inventory_dir = os.path.join(DATA_DIR, "glacier_inventory")
    if os.path.exists(inventory_dir):
        for working_file in glob.glob(os.path.join(inventory_dir, "*.working.json")):
            vault_name = os.path.basename(working_file).replace("inventory_", "").replace(".working.json", "")
            original_file = working_file.replace(".working.json", ".json")

            try:
                with open(working_file, 'r') as f:
                    working_data = json.load(f)
                    remaining = len(working_data.get("ArchiveList", []))

                total = remaining
                if os.path.exists(original_file):
                    with open(original_file, 'r') as f:
                        original_data = json.load(f)
                        total = len(original_data.get("ArchiveList", []))

                deleted = total - remaining
                progress = (deleted / total * 100) if total > 0 else 0

                status["deletion_progress"][vault_name] = {
                    "total": total,
                    "deleted": deleted,
                    "remaining": remaining,
                    "progress": round(progress, 2)
                }
            except Exception as e:
                print(f"Error reading progress {working_file}: {e}")

    # Read latest logs
    log_dir = os.path.join(DATA_DIR, "glacier_logs")
    if os.path.exists(log_dir):
        log_files = sorted(glob.glob(os.path.join(log_dir, "deletion_*.log")), reverse=True)
        if log_files:
            latest_log = log_files[0]
            try:
                with open(latest_log, 'r') as f:
                    lines = f.readlines()
                    status["logs"] = [line.strip() for line in lines[-50:]]  # Dernières 50 lignes
                    status["latest_log_file"] = os.path.basename(latest_log)
            except Exception as e:
                print(f"Error reading log: {e}")

    # Add running processes
    status["running_processes"] = list(running_processes.keys())

    return status


def check_job_status(vault_name, job_id):
    """Vérifie le statut d'un job Glacier via AWS CLI"""
    try:
        result = subprocess.run(
            ["aws", "glacier", "describe-job",
             "--account-id", "-",
             "--vault-name", vault_name,
             "--job-id", job_id,
             "--region", "eu-west-1"],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode == 0:
            job_data = json.loads(result.stdout)
            return {
                "completed": job_data.get("Completed", False),
                "statusCode": job_data.get("StatusCode", "Unknown"),
                "statusMessage": job_data.get("StatusMessage", "")
            }
    except Exception as e:
        print(f"Error checking job {vault_name}: {e}")

    return {"completed": False, "statusCode": "Unknown", "statusMessage": "Verification error"}


def run_script_async(script_name, args=None):
    """Run a bash script in background"""
    script_path = os.path.join(SCRIPTS_DIR, script_name)

    if not os.path.exists(script_path):
        return {"success": False, "error": f"Script .* not found"}

    if script_name in running_processes:
        return {"success": False, "error": f"Script .* is already running"}

    cmd = [script_path]
    if args:
        cmd.extend(args)

    def run_process():
        try:
            print(f"Launching {script_name} with args: {args}")
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=ROOT_DIR  # Execute from root for access to data/ and scripts/ folders
            )
            running_processes[script_name] = process

            stdout, stderr = process.communicate()

            # Supprimer le processus de la liste
            if script_name in running_processes:
                del running_processes[script_name]

            print(f"Script {script_name} completed with code: {process.returncode}")

        except Exception as e:
            print(f"Execution error {script_name}: {e}")
            if script_name in running_processes:
                del running_processes[script_name]

    thread = threading.Thread(target=run_process, daemon=True)
    thread.start()

    return {"success": True, "message": f"Script {script_name} launched in background"}


class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler for the dashboard"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)

        if parsed_path.path == '/api/status':
            # API: retourner le statut en JSON
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()

            status = get_vault_status()
            self.wfile.write(json.dumps(status, indent=2).encode())
            return

        elif parsed_path.path == '/' or parsed_path.path == '/dashboard':
            # Serve the dashboard HTML page
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()

            dashboard_html = os.path.join(WEB_DIR, "dashboard.html")
            if os.path.exists(dashboard_html):
                with open(dashboard_html, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.wfile.write(b"<h1>Error: dashboard.html not found</h1>")
            return

        else:
            # For other files (CSS, JS, etc.), use default handler
            super().do_GET()

    def do_POST(self):
        """Handle POST requests to run scripts"""
        parsed_path = urlparse(self.path)

        if parsed_path.path.startswith('/api/run/'):
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else '{}'

            try:
                data = json.loads(body) if body else {}
            except:
                data = {}

            script_name = parsed_path.path.replace('/api/run/', '')

            script_map = {
                'init': ('init_glacier_inventory.sh', []),
                'check': ('check_glacier_jobs.sh', []),
                'delete': ('delete_glacier_auto.sh', []),
                'delete-dry-run': ('delete_glacier_auto.sh', ['--dry-run']),
                'delete-vaults-only': ('delete_glacier_auto.sh', ['--vaults-only'])
            }

            if script_name in script_map:
                script_file, args = script_map[script_name]
                result = run_script_async(script_file, args)

                self.send_response(200 if result.get('success') else 400)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())
            else:
                self.send_response(404)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "error": "Unknown script"}).encode())

            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        """Custom logging"""
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {format % args}")


def main():
    """Start the web server"""
    print("=" * 60)
    print("🚀 Dashboard AWS Glacier")
    print("=" * 60)
    print(f"Server started on: http://localhost:{PORT}")
    print(f"Root directory: {ROOT_DIR}")
    print(f"  - Data: {DATA_DIR}")
    print(f"  - Scripts: {SCRIPTS_DIR}")
    print(f"  - Web: {WEB_DIR}")
    print("")
    print("Open your browser at: http://localhost:8080")
    print("")
    print("Press Ctrl+C to stop the server")
    print("=" * 60)
    print("")

    with socketserver.TCPServer(("", PORT), DashboardHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n🛑 Stopping server...")
            httpd.shutdown()


if __name__ == "__main__":
    main()
