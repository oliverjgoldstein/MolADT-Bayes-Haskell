ROOT_MAKE := $(MAKE) -C ..

.PHONY: help haskell-test haskell-demo haskell-infer-benchmark showcase

help:
	$(ROOT_MAKE) help

haskell-test:
	$(ROOT_MAKE) haskell-test

haskell-demo:
	$(ROOT_MAKE) haskell-demo

haskell-infer-benchmark:
	$(ROOT_MAKE) haskell-infer-benchmark

showcase:
	$(ROOT_MAKE) showcase
