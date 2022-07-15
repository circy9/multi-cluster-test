package main

import (
	"fmt"
	"k8s.io/client-go/tools/clientcmd"
	k8sapi "k8s.io/client-go/tools/clientcmd/api"
)

func main() {
	input := k8sapi.Config{
		Kind:        "Config",
		APIVersion:  "v1",
		Preferences: k8sapi.Preferences{},
		Clusters: map[string]*k8sapi.Cluster{"test-cluster": &k8sapi.Cluster{
			Server:                   "https://20.62.99.2:6443",
			CertificateAuthorityData: []byte("aGVsbG8="),
		}},
		AuthInfos:      nil,
		Contexts:       nil,
		CurrentContext: "",
		Extensions:     nil,
	}
	fmt.Printf("input: %#v\n\n", input)

	encoded, err := clientcmd.Write(input)
	if err != nil {
		fmt.Printf("encode failed %#v\n\n", err)
	}
	fmt.Printf("encoded: %#v\n\n", encoded)

	decoded, err2 := clientcmd.Load(encoded)
	if err != nil {
		fmt.Printf("decode failed %#v\n\n", err2)
	}
	fmt.Printf("decoded: %#v\n\n", decoded)
}
