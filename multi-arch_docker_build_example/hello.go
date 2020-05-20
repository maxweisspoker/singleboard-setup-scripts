package main

// Example taken from:
// https://starkandwayne.com/blog/building-docker-images-for-kubernetes-on-arm/
// https://mirailabs.io/blog/multiarch-docker-with-buildx/

import (
        "fmt"
        "runtime"
        "io/ioutil"
)

func main() {
        fmt.Printf("Hello, %s!\n\n", runtime.GOARCH)
        content, err := ioutil.ReadFile("/proc/cpuinfo")
        _ = err
        text := string(content)
        fmt.Println(text)
}
