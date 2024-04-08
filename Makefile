
CONTAINER_NAME = btburke/infer
CONTAINER_TAG != date +"%Y.%m.%d-%H%M" # datetime based semver
MODEL = sakura-solar-instruct.Q5_K_M.gguf
MODEL_URL = https://huggingface.co/TheBloke/Sakura-SOLAR-Instruct-GGUF/resolve/main/sakura-solar-instruct.Q5_K_M.gguf
CUDA_VERSION = 12.2.0

# cuBLAS and CUDA support
infer: force_look
	@echo "INFO: Building production with cuBLAS and CUDA bindings"
	cd llama.cpp; $(MAKE) LLAMA_CUDA=1 LLAMA_CUDA_F16=1 && cp main ../infer

# CPU only, no CUDA
infer-cpu: force_look
	@echo "INFO: Building CPU-only inference"
	cd llama.cpp; $(MAKE) && cp main ../infer-cpu
	rm -f infer
	ln -s ./infer-cpu ./infer

models/$(MODEL):
	mkdir -p models
	cd models; wget -q -O ${MODEL} ${MODEL_URL}

.PHONY: container
container: models/$(MODEL)
	@echo "Building docker version ${CONTAINER_TAG}"
	podman login docker.io
	podman build -t docker.io/${CONTAINER_NAME}:${CONTAINER_TAG}-cuda${CUDA_VERSION} --build-arg CUDA_VERSION=${CUDA_VERSION} --build-arg MODEL=${MODEL} --format docker .
	podman push docker.io/${CONTAINER_NAME}:${CONTAINER_TAG}-cuda${CUDA_VERSION}
	@echo "Finished docker.io/${CONTAINER_NAME}:${CONTAINER_TAG}-cuda${CUDA_VERSION}"

.PHONY: clean
clean:
	rm -f llama*.log
	rm -f infer infer-cpu
	cd llama.cpp; $(MAKE) clean

.PHONY: test
test: infer models/$(MODEL)
	./infer -m models/$(MODEL) -t 4 --prompt "### System: Say hello. ### Assistant: " -n 128

.PHONY: test-complex
test-complex: infer models/$(MODEL) test_prompt.txt
	./infer -m models/$(MODEL) -n 256 -t 4 --file test_prompt.txt

force_look :
	true
