package main

/*
#cgo LDFLAGS: -lpthread
#cgo darwin LDFLAGS: -framework IOKit -framework CoreFoundation
#cgo linux LDFLAGS: -lusb-1.0

#include "yocto_wrapper.h"
#include <stdlib.h>
*/
import "C"

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"unsafe"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	gauges = make(map[string]*prometheus.GaugeVec)
)

func main() {
	var (
		listenAddress = flag.String("listen-address", ":8000", "The address to listen on for HTTP requests.")
		metricsPath   = flag.String("metrics-path", "/metrics", "Path under which to serve metrics.")
		hubURL        = flag.String("hub-url", "usb", "Yoctopuce Hub URL (e.g., 'usb', '127.0.0.1:4444', '192.168.1.10').")
	)
	flag.Parse()

	errmsg := C.malloc(256)
	defer C.free(errmsg)

	cHubURL := C.CString(*hubURL)
	defer C.free(unsafe.Pointer(cHubURL))

	if res := C.yocto_RegisterHub(cHubURL, (*C.char)(errmsg), 256); res != 0 {
		fmt.Printf("Init error: %s\n", C.GoString((*C.char)(errmsg)))
		os.Exit(1)
	}
	defer C.yocto_FreeAPI()

	// Create a custom collector to update gauges on every scrape
	exporter := &YoctoExporter{}
	prometheus.MustRegister(exporter)

	http.Handle(*metricsPath, promhttp.Handler())
	fmt.Printf("Starting exporter on %s%s monitoring hub '%s'\n", *listenAddress, *metricsPath, *hubURL)
	log.Fatal(http.ListenAndServe(*listenAddress, nil))
}

type YoctoExporter struct{}

func (e *YoctoExporter) Describe(ch chan<- *prometheus.Desc) {
	// Dynamically described during Collect
}

func (e *YoctoExporter) Collect(ch chan<- prometheus.Metric) {
	var errBuf [256]C.char
	C.yocto_UpdateCheck(&errBuf[0], 256)

	s := C.yocto_FirstSensor()
	for s != nil {
		var buf [256]C.char

		C.yocto_GetFunctionId(s, &buf[0], 256)
		funcId := C.GoString(&buf[0])

		C.yocto_GetUnit(s, &buf[0], 256)
		unit := C.GoString(&buf[0])

		C.yocto_GetHardwareId(s, &buf[0], 256)
		hwId := C.GoString(&buf[0])

		val := float64(C.yocto_GetCurrentValue(s))

		gauge, ok := gauges[funcId]
		if !ok {
			gauge = prometheus.NewGaugeVec(prometheus.GaugeOpts{
				Name: funcId,
				Help: "Current " + funcId + " reading",
			}, []string{"unit", "hardwareId"})
			gauges[funcId] = gauge
			// Note: In a production environment, you might want to pre-register or handle registration concurrency better.
			// But for Collect, we can just return the metric.
		}

		m, err := gauge.GetMetricWithLabelValues(unit, hwId)
		if err == nil {
			m.Set(val)
			m.Collect(ch)
		}

		s = C.yocto_NextSensor(s)
	}
}
