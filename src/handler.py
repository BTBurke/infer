""" Example handler file. """

import runpod
import subprocess
import sys
import httpx
import uuid
import os
from urllib.parse import urlparse

# If your handler runs inference on a model, load the model here.
# You will want models to be loaded into memory before starting serverless.
model_url = "https://huggingface.co/TheBloke/Sakura-SOLAR-Instruct-GGUF/resolve/main/sakura-solar-instruct.Q5_K_M.gguf"
# directory to save models in
model_dir = os.getenv("MODEL_DIR", "/runpod-volume/models")

def download():
    print(f"Downloading model from {model_url}")
    print(f"Saving model to path {model_file}")
    if os.path.exists(model_file):
        return
    if os.path.dirname(model_file):
        os.makedirs(os.path.dirname(model_file), exist_ok=True)
    with httpx.Client() as client:
        with client.stream("GET", model_url, follow_redirects=True) as resp:
            tmp_path = f"{model_file}.{uuid.uuid4()}.tmp"
            with open(tmp_path, "wb") as out_file:
                for chunk in resp.iter_raw():
                    out_file.write(chunk)

    os.rename(tmp_path, model_file)
    return

def handler(job):
    """ Handler function that will be used to process jobs. """
    job_input = job['input']
    prompt = job_input['prompt']
    print("Running with prompt: {}".format(prompt))
    
    process = subprocess.Popen(["./infer", "-m", model_file], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, stderr = process.communicate(input=prompt)
    sys.stderr.buffer.write(stderr.encode('utf-8'))

    return stdout.encode('utf-8')

model_file = os.path.join(model_dir, os.path.split(urlparse(model_url).path)[1])
download()
runpod.serverless.start({"handler": handler})
