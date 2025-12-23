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
	"strings"
	"unsafe"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/common/expfmt"
)

var (
	version = "dev"
)

type stringMap map[string]string

func (m stringMap) String() string {
	return fmt.Sprintf("%v", map[string]string(m))
}

func (m stringMap) Set(value string) error {
	parts := strings.SplitN(value, "=", 2)
	if len(parts) != 2 {
		return fmt.Errorf("invalid format, expected key=value")
	}
	m[parts[0]] = parts[1]
	return nil
}

func main() {
	var (
		listenAddress = flag.String("listen-address", ":8000", "The address to listen on for HTTP requests.")
		metricsPath   = flag.String("metrics-path", "/metrics", "Path under which to serve metrics.")
		hubURL        = flag.String("hub-url", "usb", "Yoctopuce Hub URL (e.g., 'usb', '127.0.0.1:4444', '192.168.1.10').")
		oneshot       = flag.Bool("oneshot", false, "Run once and output metrics to stdout, then exit.")
		showVersion   = flag.Bool("version", false, "Print version information and exit.")
		unitOverrides = make(stringMap)
	)
	flag.Var(&unitOverrides, "override-unit", "Override unit for a specific functionId (e.g., -override-unit temperature='C). Can be repeated.")
	flag.Parse()

	if *showVersion {
		fmt.Printf("yocto-exporter version %s\n", version)
		os.Exit(0)
	}

	errmsg := C.malloc(256)
	defer C.free(errmsg)

	cHubURL := C.CString(*hubURL)
	defer C.free(unsafe.Pointer(cHubURL))

	if res := C.yocto_RegisterHub(cHubURL, (*C.char)(errmsg), 256); res != 0 {
		fmt.Printf("Init error: %s\n", C.GoString((*C.char)(errmsg)))
		os.Exit(1)
	}
	C.yocto_AllSensorsInit()
	defer C.yocto_FreeAPI()

	// Create a custom collector to update gauges on every scrape
	exporter := &YoctoExporter{
		unitOverrides: unitOverrides,
		gauges:        make(map[string]*prometheus.GaugeVec),
	}

	if *oneshot {
		reg := prometheus.NewRegistry()
		reg.MustRegister(exporter)

		mfs, err := reg.Gather()
		if err != nil {
			log.Fatalf("Error gathering metrics: %v", err)
		}

		enc := expfmt.NewEncoder(os.Stdout, expfmt.FmtText)
		for _, mf := range mfs {
			if err := enc.Encode(mf); err != nil {
				log.Fatalf("Error encoding metric: %v", err)
			}
		}
		return
	}

	prometheus.MustRegister(exporter)

	http.Handle(*metricsPath, promhttp.Handler())
	fmt.Printf("Starting exporter on %s%s monitoring hub '%s'\n", *listenAddress, *metricsPath, *hubURL)
	log.Fatal(http.ListenAndServe(*listenAddress, nil))
}

type YoctoExporter struct {
	unitOverrides map[string]string
	gauges        map[string]*prometheus.GaugeVec
}

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
		unit := strings.ToValidUTF8(C.GoString(&buf[0]), "?")
		if override, ok := e.unitOverrides[funcId]; ok {
			unit = override
		}

		C.yocto_GetHardwareId(s, &buf[0], 256)
		hwId := C.GoString(&buf[0])

		val := float64(C.yocto_GetCurrentValue(s))

		gauge, ok := e.gauges[funcId]
		if !ok {
			gauge = prometheus.NewGaugeVec(prometheus.GaugeOpts{
				Name: funcId,
				Help: "Current " + funcId + " reading",
			}, []string{"unit", "hardwareId"})
			e.gauges[funcId] = gauge
		}

		m, err := gauge.GetMetricWithLabelValues(unit, hwId)
		if err == nil {
			m.Set(val)
			m.Collect(ch)
		}

		s = C.yocto_NextSensor(s)
	}
}
