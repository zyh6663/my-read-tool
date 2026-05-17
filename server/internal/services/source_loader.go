package services

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"

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

var sourceRulesOnce sync.Once
var cachedSources []LoadedSource
var cachedSourceErr error

func LoadEnabledSources() ([]LoadedSource, error) {
	sourceRulesOnce.Do(func() {
		var sources []models.BookSource
		if err := database.DB.Where("enabled = ?", true).Order("priority desc, id desc").Find(&sources).Error; err != nil {
			cachedSourceErr = err
			return
		}
		for _, src := range sources {
			var rule SourceRule
			if err := json.Unmarshal([]byte(src.RuleJSON), &rule); err != nil {
				continue
			}
			cachedSources = append(cachedSources, LoadedSource{BookSource: src, Rule: rule})
		}
	})
	return cachedSources, cachedSourceErr
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
		var src models.BookSource
		if err := json.Unmarshal(b, &src); err != nil {
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