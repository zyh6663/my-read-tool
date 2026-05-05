package services

import (
	"fmt"
	"sync"
)

// registry 是全局的解析器注册表（并发安全）。
// 各解析器通过 init() 函数调用 RegisterParser 自动注册。
var (
	registryMu sync.RWMutex
	registry   = make(map[string]BookParser)
)

// RegisterParser 注册一个解析器到全局注册表。
// 该函数由各解析器包的 init() 自动调用，并发安全。
// 如果一个格式被重复注册，会触发 panic（避免静默覆盖）。
func RegisterParser(p BookParser) {
	registryMu.Lock()
	defer registryMu.Unlock()

	for _, format := range p.SupportedFormats() {
		if _, exists := registry[format]; exists {
			panic(fmt.Sprintf("parser for format %q already registered", format))
		}
		registry[format] = p
	}
}

// GetParser 根据格式（小写扩展名，不含点号）获取解析器。
// 如果格式不被支持，返回 FormatNotSupportedError。
func GetParser(format string) (BookParser, error) {
	registryMu.RLock()
	defer registryMu.RUnlock()

	p, ok := registry[format]
	if !ok {
		return nil, &FormatNotSupportedError{Format: format}
	}
	return p, nil
}

// SupportedFormats 返回所有已注册的支持格式列表。
func SupportedFormats() []string {
	registryMu.RLock()
	defer registryMu.RUnlock()

	formats := make([]string, 0, len(registry))
	for f := range registry {
		formats = append(formats, f)
	}
	return formats
}