
DOCKER_TAG != date +"%Y.%m.%d-%H%M"
MODEL = "sakura-solar-instruct.Q5_K_M.gguf"
MODEL_URL = "https://huggingface.co/TheBloke/Sakura-SOLAR-Instruct-GGUF/resolve/main/sakura-solar-instruct.Q5_K_M.gguf"

infer: main.go go-llama.cpp/libbinding.a models/$(MODEL)
ifeq ($(ENV), "prod")
	@echo "INFO: Building production with cuBLAS and CUDA bindings"
	CGO_LDFLAGS="-lcublas -lcudart -L/usr/local/cuda/lib64/" LIBRARY_PATH=./go-llama.cpp C_INCLUDE_PATH=./go-llama.cpp go build -o infer main.go
else
	@echo "INFO: Building CPU-only inferfence"
	LIBRARY_PATH=./go-llama.cpp C_INCLUDE_PATH=./go-llama.cpp go build -o infer main.go
endif

models/$(MODEL):
	mkdir -p models
	cd models; wget -q $(MODEL_URL)

go-llama.cpp/libbinding.a: force_look
ifeq ($(ENV), "prod")
	cd go-llama.cpp; BUILD_TYPE=cublas $(MAKE) libbinding.a
else
	cd go-llama.cpp; $(MAKE) libbinding.a
endif

.PHONY: docker
docker:
	@echo "Building docker version ${DOCKER_TAG}"
	CUDA_VERSION=12.2.0 $(MAKE) _docker

.PHONY: _docker
_docker:
	docker build -t btburke/infer:${DOCKER_TAG}-cuda${CUDA_VERSION} --build-arg CUDA_VERSION=${CUDA_VERSION} --build-arg MODEL=${MODEL} .
	docker push btburke/infer:${DOCKER_TAG}-cuda${CUDA_VERSION}

clean:
	rm llama*.log
	rm infer
	cd go-llama.cpp; $(MAKE) clean

force_look :
	true
