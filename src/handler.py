""" Example handler file. """

import runpod
import subprocess
import sys
import httpx
import uuid
import os
from urllib.parse import urlparse
import glob

# If your handler runs inference on a model, load the model here.
# You will want models to be loaded into memory before starting serverless.
model_name = "sakura-solar-instruct.Q5_K_M.gguf"
# directory to save models in
model_dir = os.getenv("MODEL_DIR", "/models")

def download(model_url, model_file):
    print(f"Downloading model from {model_url}")
    print(f"Saving model to path {model_file}")
    if os.path.exists(model_file):
        return
    if os.path.dirname(model_file):
        os.makedirs(os.path.dirname(model_file), exist_ok=True)
    for f in glob.glob(os.path.join(os.path.dirname(model_file), "*.tmp")):
        print(f"Deleting aborted download {f}")
        os.remove(f)
    with httpx.Client() as client:
        with client.stream("GET", model_url, follow_redirects=True) as resp:
            tmp_path = f"{model_file}.{uuid.uuid4()}.tmp"
            with open(tmp_path, "wb") as out_file:
                for chunk in resp.iter_raw():
                    out_file.write(chunk)

    os.rename(tmp_path, model_file)
    return

def handler(job):
    model_file = os.path.join(model_dir, model_name)
    print(f"Running with model file {model_file}")
    job_input = job['input']
    prompt = job_input['prompt']
    print("Running with prompt: {}".format(prompt))
    
    process = subprocess.run(["./infer", "-m", model_file, "-ngl", "51", "--prompt", prompt, "-n", "512", "-t", str(os.cpu_count())], capture_output=True)
    sys.stderr.buffer.write(process.stderr)

    # llama returns full prompt in output, strip the prompt and just keep the generated text
    return process.stdout.decode('utf-8').replace(prompt, "").strip().encode('utf-8')

runpod.serverless.start({"handler": handler})
