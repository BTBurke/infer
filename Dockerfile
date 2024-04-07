ARG CUDA_VERSION=11.8.0
ARG RUNPOD_VERSION=0.6.2
FROM docker.io/runpod/base:${RUNPOD_VERSION}-cuda${CUDA_VERSION} as builder

RUN mkdir -p /workspace
WORKDIR /workspace

COPY . .
RUN make infer ENV="prod"

## Base image -> https://github.com/runpod/containers/blob/main/official-templates/base/Dockerfile
## DockerHub -> https://hub.docker.com/r/runpod/base/tags
FROM docker.io/runpod/base:${RUNPOD_VERSION}-cuda${CUDA_VERSION}
#
## The base image comes with many system dependencies pre-installed to help you get started quickly.
## Please refer to the base image's Dockerfile for more information before adding additional dependencies.
## IMPORTANT: The base image overrides the default huggingface cache location.
#
## Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN python3.11 -m pip install --upgrade pip && \
    python3.11 -m pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

ARG MODEL
COPY --from=builder /workspace/infer .
RUN mkdir -p /models
COPY models/${MODEL} /models/${MODEL}
ADD src .
CMD python3.11 -u /handler.py
