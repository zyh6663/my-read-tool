package services

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"purereader-server/internal/models"
	"purereader-server/pkg/database"
)

type SourceRule struct {
	Search       SearchRule  `json:"search"`
	Detail       DetailRule  `json:"detail"`
	Chapter      ChapterRule `json:"chapter_content"`
	ResponseType string      `json:"response_type"` // "html" 或 "json"，默认 "html"
}

type SearchRule struct {
	URL          string            `json:"url"`
	Method       string            `json:"method"`
	ListSelector string            `json:"list_selector"`
	Fields       map[string]string `json:"fields"`
}

type DetailRule struct {
	URL                 string            `json:"url"`
	ChapterListSelector string            `json:"chapter_list_selector"`
	Fields              map[string]string `json:"fields"`
}

type ChapterRule struct {
	ContentSelector string   `json:"content_selector"`
	RemoveSelectors []string `json:"remove_selectors"`
}

type LoadedSource struct {
	models.BookSource
	Rule SourceRule
}


func LoadEnabledSources() ([]LoadedSource, error) {
	var sources []models.BookSource
	if err := database.DB.Where("enabled = ?", true).Order("priority desc, id desc").Find(&sources).Error; err != nil {
		return nil, err
	}
	var result []LoadedSource
	for _, src := range sources {
		var rule SourceRule
		if err := json.Unmarshal([]byte(src.RuleJSON), &rule); err != nil {
			continue
		}
		result = append(result, LoadedSource{BookSource: src, Rule: rule})
	}
	return result, nil
}

func ReloadBuiltinSources() error {
	entries, err := os.ReadDir("server/config/sources")
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(strings.ToLower(entry.Name()), ".json") {
			continue
		}
		path := filepath.Join("server/config/sources", entry.Name())
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		// 先用 map 解析，把 rule_json 对象转成字符串
		var raw map[string]interface{}
		if err := json.Unmarshal(b, &raw); err != nil {
			return fmt.Errorf("parse builtin source %s: %w", path, err)
		}
		if ruleObj, ok := raw["rule_json"]; ok {
			if ruleBytes, err := json.Marshal(ruleObj); err == nil {
				raw["rule_json"] = string(ruleBytes)
			}
		}
		// 重新序列化后再反序列化到 BookSource
		fixed, err := json.Marshal(raw)
		if err != nil {
			return fmt.Errorf("re-marshal builtin source %s: %w", path, err)
		}
		var src models.BookSource
		if err := json.Unmarshal(fixed, &src); err != nil {
			return fmt.Errorf("parse builtin source %s: %w", path, err)
		}
		src.IsBuiltin = true
		if err := database.DB.Where("base_url = ?", src.BaseURL).Assign(src).FirstOrCreate(&models.BookSource{}).Error; err != nil {
			return err
		}
	}
	return nil
}

func SortSourcesByPriority(items []LoadedSource) {
	sort.Slice(items, func(i, j int) bool { return items[i].Priority > items[j].Priority })
}