# GOOS: linux | darwin
GOOS      := linux
GOARCH    := amd64
ARTIFACT  := frontback.tgz
S3_BUCKET := hashicorpjp
S3_OBJECT := masa/meshgateway_proxy_demo/${ARTIFACT}

all: deploy 

frontend: frontend.go
	GOOS=${GOOS} GOARCH=${GOARCH} go build -o $@ $^

backend: backend.go
	GOOS=${GOOS} GOARCH=${GOARCH} go build -o $@ $^

${ARTIFACT}: frontend backend cleanup.sh setup_fe.sh setup_be.sh start_proxy_for_fe.sh start_proxy_for_be.sh
	tar cfpz ${ARTIFACT} $^

deploy: ${ARTIFACT}
	aws s3 cp $^ s3://${S3_BUCKET}/${S3_OBJECT}
	aws s3api put-object-acl --bucket ${S3_BUCKET} --key ${S3_OBJECT} --acl public-read

mac: frontend.go backend.go
	GOOS=darwin GOARCH=${GOARCH} go build -o backend_mac backend.go
	GOOS=darwin GOARCH=${GOARCH} go build -o frontend_mac frontend.go

clean:
	rm -f frontend backend frontend_mac backend_mac ${ARTIFACT}
