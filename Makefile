.PHONY: build test run

IMAGE_NAME ?= ghcr.io/ministryofjustice/analytical-platform-airflow-r-base
IMAGE_TAG  ?= local
comma := ,
BUILD_CA_SECRET = $(if $(BUILD_CA_BUNDLE),--secret "id=build_ca_bundle$(comma)src=$(BUILD_CA_BUNDLE)")

run: build
	docker run --rm -it $(IMAGE_NAME):$(IMAGE_TAG)

test: build
	container-structure-test test --platform linux/amd64 --config test/container-structure-test.yml --image $(IMAGE_NAME):$(IMAGE_TAG)

build:
	@ARCH=`uname --machine`; \
	case $$ARCH in \
	aarch64 | arm64) \
		echo "Building on $$ARCH architecture"; \
		docker build --platform linux/amd64 $(BUILD_CA_SECRET) --file Dockerfile --tag $(IMAGE_NAME):$(IMAGE_TAG) . ;; \
	*) \
		echo "Building on $$ARCH architecture"; \
		docker build $(BUILD_CA_SECRET) --file Dockerfile --tag $(IMAGE_NAME):$(IMAGE_TAG) . ;; \
	esac
