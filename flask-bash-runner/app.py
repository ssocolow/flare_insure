from flask import Flask, jsonify
import subprocess
import os
import threading
import uuid

app = Flask(__name__)

# Store script results
script_results = {}

# Get the absolute path to the script
SCRIPT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "testScript.sh")
print(f"Looking for script at: {SCRIPT_PATH}")  # Debug print

# Simple health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "script_path": SCRIPT_PATH,
        "script_exists": os.path.exists(SCRIPT_PATH)
    })

def run_script_async(job_id):
    try:
        print(f"Current working directory: {os.getcwd()}")  # Debug print
        print(f"Script path: {SCRIPT_PATH}")  # Debug print
        print(f"Script exists: {os.path.exists(SCRIPT_PATH)}")  # Debug print
        
        # Make sure script is executable
        os.chmod(SCRIPT_PATH, 0o755)
        
        script_dir = os.path.dirname(SCRIPT_PATH)
        result = subprocess.run(
            [SCRIPT_PATH],
            capture_output=True,
            text=True,
            timeout=300,
            cwd=script_dir
        )
        script_results[job_id] = {
            "status": "completed",
            "stdout": result.stdout,
            "stderr": result.stderr,
            "return_code": result.returncode
        }
    except Exception as e:
        script_results[job_id] = {
            "status": "failed",
            "error": str(e),
            "details": f"CWD: {os.getcwd()}, Script Path: {SCRIPT_PATH}"  # More debug info
        }

# ASYNC SO IMMEDIATE RETURN FRO API CALL
@app.route('/run', methods=['POST'])
def start_script():
    job_id = str(uuid.uuid4())
    script_results[job_id] = {"status": "running"}
    
    # Start script in background
    thread = threading.Thread(target=run_script_async, args=(job_id,))
    thread.start()
    
    return jsonify({
        "job_id": job_id,
        "status": "running"
    })

@app.route('/status/<job_id>', methods=['GET'])
def get_status(job_id):
    if job_id not in script_results:
        return jsonify({"error": "Job not found"}), 404
    return jsonify(script_results[job_id])

if __name__ == '__main__':
    # SWAP IF RUNNING ON EC2
    # app.run(host='0.0.0.0', port=3001)
    app.run(host='localhost', port=3001)