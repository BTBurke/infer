package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"io"
	"log/slog"
	"os"
	"runtime"
	"strings"
	"time"

	llama "github.com/go-skynet/go-llama.cpp"
)

var (
	threads   = 4
	tokens    = 4096
	gpulayers = 48
	seed      = -1
)

var jsonPrompt = "### System:\nYou are a helpful assistant who always follows directions. Respond only with a valid JSON object and nothing else. Start your response with { and end with }."

func main() {
	var model string

	flags := flag.NewFlagSet(os.Args[0], flag.ExitOnError)
	flags.StringVar(&model, "m", "./models/sakura-solar-instruct.Q5_K_M.gguf", "path to model file to load")
	flags.IntVar(&gpulayers, "ngl", 48, "Number of GPU layers to use")
	flags.IntVar(&threads, "t", 2*runtime.NumCPU(), "number of threads to use during computation")
	flags.IntVar(&tokens, "n", 512, "number of tokens to predict")
	flags.IntVar(&seed, "s", -1, "predict RNG seed, -1 for random seed")

	t0 := time.Now()
	if err := flags.Parse(os.Args[1:]); err != nil {
		slog.Error("Parsing program arguments failed: %s", "err", err)
		os.Exit(1)
	}
	l, err := llama.New(model, llama.EnableF16Memory, llama.SetContext(256), llama.EnableEmbeddings, llama.SetGPULayers(gpulayers))
	if err != nil {
		slog.Error("Loading the model failed", "err", err.Error())
		os.Exit(1)
	}
	slog.Info("Model loaded successfully", "time", time.Since(t0))

	text, err := io.ReadAll(os.Stdin)
	if err != nil {
		slog.Error("No prompt input on STDIN")
		os.Exit(1)
	}
	prompt := strings.Join([]string{jsonPrompt, string(text)}, "\n\n")

	t0 = time.Now()
	seen := 0
	out, err := l.Predict(prompt, llama.SetTokenCallback(func(token string) bool {
		seen += 1
		if seen == 1 {
			slog.Info("Starting inference", "elapsed", time.Since(t0), "tokens", seen, "got", token)
			t0 = time.Now()
		} else {
			slog.Info("Timing", "elapsed", time.Since(t0), "tokens", seen, "per_second", time.Since(t0).Seconds()/float64(tokens), "got", token)
		}
		stop := []string{"### System:", "### User:", "### Context:", "### Assistant:"}
		for _, stopW := range stop {
			if strings.Contains(token, stopW) {
				return false
			}
		}
		return true
	}), llama.SetTokens(tokens), llama.SetThreads(threads), llama.SetTopK(90), llama.SetTopP(0.86), llama.SetSeed(seed))
	if err != nil {
		slog.Error("error in inference", "err", err)
		os.Exit(1)
	}

	// check JSON output
	var outDec map[string]any
	if err := json.Unmarshal([]byte(out), &outDec); err != nil {
		slog.Error("LLM output not valid JSON", "err", err, "data", out)
		os.Exit(1)
	}
	outEnc, err := json.Marshal(outDec)
	if err != nil {
		slog.Error("Error re-encoding to JSON", "err", err, "data", outDec)
		os.Exit(1)
	}

	if _, err := io.Copy(os.Stdout, bytes.NewReader(outEnc)); err != nil {
		slog.Error("Error writing to STDOUT", "err", err)
		os.Exit(1)
	}
	slog.Info("Inference complete", "time", time.Since(t0), "tokens", tokens)
}
