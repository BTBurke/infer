
DOCKER_TAG != date +"%Y.%m.%d-%H%M"
MODEL = sakura-solar-instruct.Q5_K_M.gguf
MODEL_URL = https://huggingface.co/TheBloke/Sakura-SOLAR-Instruct-GGUF/resolve/main/sakura-solar-instruct.Q5_K_M.gguf
ENV ?= "prod"

infer: force_look
ifeq ($(ENV), "prod")
	@echo "INFO: Building production with cuBLAS and CUDA bindings"
	cd llama.cpp; $(MAKE) LLAMA_CUDA=1 LLAMA_CUDA_F16=1 && cp main ../infer
else
	@echo "INFO: Building CPU-only inferfence"
	cd llama.cpp; $(MAKE) && cp main ../infer
endif

models/$(MODEL):
	mkdir -p models
	cd models; wget -q $(MODEL_URL)

docker: models/$(MODEL)
	@echo "Building docker version ${DOCKER_TAG}"
	CUDA_VERSION=12.2.0 $(MAKE) _docker

.PHONY: _docker
_docker:
	docker build -t btburke/infer:${DOCKER_TAG}-cuda${CUDA_VERSION} --build-arg CUDA_VERSION=${CUDA_VERSION} --build-arg MODEL=${MODEL} .
	docker push btburke/infer:${DOCKER_TAG}-cuda${CUDA_VERSION}

clean:
	rm -f llama*.log
	rm -f main
	cd llama.cpp; $(MAKE) clean

.PHONY: test
test: infer models/$(MODEL)
	./infer -m models/$(MODEL) -t 4 --prompt "### System: Say hello. ### Assistant: " -n 128

.PHONY: test-complex
test-complex: infer models/$(MODEL) test_prompt.txt
	./infer -m models/$(MODEL) -n 256 -t 4 --file test_prompt.txt

force_look :
	true
