package services

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"strings"
)

func ValidateSourceRule(ruleJSON string) error {
	if strings.TrimSpace(ruleJSON) == "" {
		return errors.New("规则不能为空")
	}

	var payload map[string]any
	if err := json.Unmarshal([]byte(ruleJSON), &payload); err != nil {
		return fmt.Errorf("规则JSON格式错误: %w", err)
	}

	for _, key := range []string{"base_url", "baseUrl", "url", "source_url"} {
		if v, ok := payload[key]; ok {
			baseURL, _ := v.(string)
			if err := validateSourceURL(baseURL); err != nil {
				return err
			}
		}
	}

	return nil
}

func validateSourceURL(raw string) error {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parsed, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("来源地址无效: %w", err)
	}
	if parsed.Scheme == "file" {
		return errors.New("禁止使用 file:// 协议")
	}
	host := strings.ToLower(parsed.Hostname())
	if host == "localhost" || host == "127.0.0.1" || host == "::1" {
		return errors.New("禁止使用 localhost 地址")
	}
	return nil
}
