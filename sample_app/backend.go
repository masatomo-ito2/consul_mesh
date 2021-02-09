/*
 * Written by Masa Ito (masa@hashicorp.com) for snapshots
 */

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
)

//User defines model for storing account details in database
type Resp struct {
	Color    string
	Addr     string
	Mode     string
	TaskId   string
	Pid      string
	PublicIP string
	Version  string
	ImgSrc   string
}

func respHandler(w http.ResponseWriter, r *http.Request) {
	// Obtain own public IP address
	// url := "http://169.254.169.254/latest/meta-data/public-ipv4"
	resp := Resp{
		Color:    os.Getenv("COLOR"),
		Addr:     os.Getenv("ADDR"),
		Mode:     os.Getenv("MODE"),
		TaskId:   os.Getenv("TASK_ID"),
		Pid:      strconv.Itoa(os.Getpid()),
		PublicIP: os.Getenv("PUBLIC_IP"),
		Version:  os.Getenv("VERSION"),
		ImgSrc:   os.Getenv("IMG_SRC"),	
	}

	// Marshal user object back to json
	respJson, err := json.Marshal(resp)
	if err != nil {
		panic(err)
	}

	fmt.Println(string(respJson))

	// Set Content-Type header so that clients will know how to read response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	// Write json response back to response
	w.Write(respJson)
}

func main() {

	port := os.Getenv("PORT")

	mux := http.NewServeMux()
	server := &http.Server{
		Addr:    fmt.Sprintf("0.0.0.0:%v", port),
		Handler: mux,
	}

	mux.HandleFunc("/", respHandler)
	server.ListenAndServe()
}
