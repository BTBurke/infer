
infer: main.go go-llama.cpp/libbinding.a
ifeq ($(ENV), "prod")
	CGO_LDFLAGS="-lcublas -lcudart -L/usr/local/cuda/lib64/" LIBRARY_PATH=./go-llama.cpp C_INCLUDE_PATH=./go-llama.cpp go build -o infer main.go
else
	LIBRARY_PATH=./go-llama.cpp C_INCLUDE_PATH=./go-llama.cpp go build -o infer main.go
endif

go-llama.cpp/libbinding.a: force_look
ifeq ($(ENV), "prod")
	cd go-llama.cpp; git submodule update --init && BUILD_TYPE=cublas $(MAKE) libbinding.a
else
	cd go-llama.cpp; git submodule update --init && $(MAKE) libbinding.a
endif

clean:
	rm llama*.log
	rm infer
	cd go-llama.cpp; $(MAKE) clean

force_look :
	true
