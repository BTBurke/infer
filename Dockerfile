ARG CUDA_VERSION=12.2.0
ARG RUNPOD_VERSION=0.6.2
FROM docker.io/runpod/base:${RUNPOD_VERSION}-cuda${CUDA_VERSION} as builder
COPY . .
RUN make infer

## Base image -> https://github.com/runpod/containers/blob/main/official-templates/base/Dockerfile
## DockerHub -> https://hub.docker.com/r/runpod/base/tags
FROM docker.io/runpod/base:${RUNPOD_VERSION}-cuda${CUDA_VERSION}
# Embed model
ARG MODEL
COPY models/${MODEL} /models/${MODEL}
# add llama.cpp
COPY --from=builder /infer .
## The base image comes with many system dependencies pre-installed to help you get started quickly.
## Please refer to the base image's Dockerfile for more information before adding additional dependencies.
## IMPORTANT: The base image overrides the default huggingface cache location.
#
## Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN python3.11 -m pip install --upgrade pip && \
    python3.11 -m pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt
ADD src .
CMD python3.11 -u /handler.py
