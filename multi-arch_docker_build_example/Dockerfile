# Example taken from
# https://starkandwayne.com/blog/building-docker-images-for-kubernetes-on-arm/
# https://mirailabs.io/blog/multiarch-docker-with-buildx/

FROM golang:alpine AS builder
RUN mkdir /app
ADD . /app/
WORKDIR /app
RUN go build -o hello .

FROM alpine
RUN mkdir /app
WORKDIR /app
COPY --from=builder /app/hello .
CMD ["./hello"]

## MIPS Test
#FROM lochnair/alpine-mips64:latest
#CMD ["/bin/sh -c \"ls /\""]

