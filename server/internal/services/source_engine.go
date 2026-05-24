package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/PuerkitoBio/goquery"
	"golang.org/x/text/encoding/simplifiedchinese"
	"golang.org/x/text/transform"

	"purereader-server/internal/models"
	"purereader-server/pkg/database"
)

type SearchResult struct {
	SourceID     uint   `json:"source_id"`
	SourceName   string `json:"source_name"`
	SourceBookID string `json:"source_book_id"`
	Title        string `json:"title"`
	Author       string `json:"author"`
	Description  string `json:"description"`
	CoverURL     string `json:"cover_url"`
	ChapterCount int    `json:"chapter_count"`
}

type BookDetail struct {
	SearchResult
	Chapters []ChapterItem `json:"chapters"`
}

type ChapterItem struct {
	Index int    `json:"index"`
	Title string `json:"title"`
	URL   string `json:"url"`
}

func SearchBooks(keyword string, sourceFilter string, page int, userID string) ([]SearchResult, error) {
	sources, err := LoadEnabledSources(userID)
	if err != nil {
		return nil, err
	}
	if len(sources) == 0 {
		return []SearchResult{}, nil
	}
	// 仅搜索指定书源
	if sourceFilter != "" {
		fid, _ := strconv.ParseUint(sourceFilter, 10, 64)
		filtered := make([]LoadedSource, 0)
		for _, s := range sources {
			if s.ID == uint(fid) {
				filtered = append(filtered, s)
			}
		}
		sources = filtered
	}
	if len(sources) == 0 {
		return []SearchResult{}, nil
	}
	var wg sync.WaitGroup
	ch := make(chan []SearchResult, len(sources))
	for _, src := range sources {
		src := src
		wg.Add(1)
		go func() {
			defer wg.Done()
			if results, err := searchSource(src, keyword); err == nil && len(results) > 0 {
				ch <- results
			}
		}()
	}
	wg.Wait()
	close(ch)
	var out []SearchResult
	for item := range ch {
		out = append(out, item...)
	}
	return dedupeResults(out), nil
}

func searchSource(src LoadedSource, keyword string) ([]SearchResult, error) {
	searchURL := strings.ReplaceAll(src.Rule.Search.URL, "{keyword}", url.QueryEscape(keyword))
	if strings.HasPrefix(searchURL, "/") {
		searchURL = strings.TrimRight(src.BaseURL, "/") + searchURL
	}
	body, err := fetchHTML(searchURL)
	if err != nil {
		return nil, err
	}

	// JSON 响应分支
	if src.Rule.ResponseType == "json" && strings.HasPrefix(src.Rule.Search.ListSelector, "$.") {
		return searchSourceJSON(src, body)
	}

	// 原有 HTML/goquery 分支
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(body))
	if err != nil {
		return nil, err
	}
	var results []SearchResult
	doc.Find(src.Rule.Search.ListSelector).Each(func(_ int, sel *goquery.Selection) {
		item := SearchResult{SourceID: src.ID, SourceName: src.Name}
		item.Title = readField(sel, src.Rule.Search.Fields["title"])
		item.Author = readField(sel, src.Rule.Search.Fields["author"])
		item.Description = readField(sel, src.Rule.Search.Fields["description"])
		item.CoverURL = readAttr(sel, src.Rule.Search.Fields["cover_url"], "src")
		item.SourceBookID = readAttr(sel, src.Rule.Search.Fields["book_id"], "href")
		if item.SourceBookID == "" {
			item.SourceBookID = readField(sel, src.Rule.Search.Fields["book_id"])
		}
		if item.SourceBookID != "" {
			results = append(results, item)
		}
	})
	return results, nil
}

// searchSourceJSON 使用手写轻量 JSONPath 解析 JSON 响应
// 只支持两层路径：$.arrayKey[*] 取列表，$.fieldName 取字段值
func searchSourceJSON(src LoadedSource, body string) ([]SearchResult, error) {
	var data map[string]interface{}
	if err := json.Unmarshal([]byte(body), &data); err != nil {
		return nil, fmt.Errorf("json unmarshal: %w", err)
	}

	// 解析 ListSelector，如 "$.books[*]" → 取 "books"
	listKey := strings.TrimPrefix(src.Rule.Search.ListSelector, "$.")
	listKey = strings.TrimSuffix(listKey, "[*]")
	listKey = strings.TrimSpace(listKey)
	if listKey == "" {
		return nil, fmt.Errorf("empty list key in list_selector: %s", src.Rule.Search.ListSelector)
	}

	rawList, ok := data[listKey]
	if !ok {
		return nil, fmt.Errorf("key %q not found in json response", listKey)
	}

	arr, ok := rawList.([]interface{})
	if !ok {
		return nil, fmt.Errorf("key %q is not an array", listKey)
	}

	var results []SearchResult
	for _, elem := range arr {
		itemMap, ok := elem.(map[string]interface{})
		if !ok {
			continue
		}
		item := SearchResult{SourceID: src.ID, SourceName: src.Name}
		item.Title = jsonPathField(itemMap, src.Rule.Search.Fields["title"])
		item.Author = jsonPathField(itemMap, src.Rule.Search.Fields["author"])
		item.Description = jsonPathField(itemMap, src.Rule.Search.Fields["description"])
		item.CoverURL = jsonPathField(itemMap, src.Rule.Search.Fields["cover_url"])
		item.SourceBookID = jsonPathField(itemMap, src.Rule.Search.Fields["book_id"])
		if item.SourceBookID != "" {
			results = append(results, item)
		}
	}
	return results, nil
}

// jsonPathField 从 item map 中按 "$.fieldName" 路径取值
func jsonPathField(item map[string]interface{}, path string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return ""
	}
	// 去掉 "$." 前缀
	key := strings.TrimPrefix(path, "$.")
	if key == "" {
		return ""
	}
	val, ok := item[key]
	if !ok {
		return ""
	}
	switch v := val.(type) {
	case string:
		return strings.TrimSpace(v)
	case float64:
		return strings.TrimSpace(fmt.Sprintf("%v", v))
	default:
		return strings.TrimSpace(fmt.Sprintf("%v", v))
	}
}

func GetBookDetail(sourceID uint, sourceBookID string) (*BookDetail, error) {
	var src models.BookSource
	if err := database.DB.First(&src, sourceID).Error; err != nil {
		return nil, err
	}
	var rule SourceRule
	if err := json.Unmarshal([]byte(src.RuleJSON), &rule); err != nil {
		return nil, err
	}
	// 使用 detail.url 模板构建 URL，支持 {book_id} 占位符
	detailURL := rule.Detail.URL
	if detailURL == "" {
		detailURL = sourceBookID
	}
	bookURL := strings.ReplaceAll(detailURL, "{book_id}", url.QueryEscape(sourceBookID))
	if strings.HasPrefix(bookURL, "/") {
		bookURL = strings.TrimRight(src.BaseURL, "/") + bookURL
	}
	body, err := fetchHTML(bookURL)
	if err != nil {
		return nil, err
	}
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(body))
	if err != nil {
		return nil, err
	}
	detail := &BookDetail{SearchResult: SearchResult{SourceID: src.ID, SourceName: src.Name, SourceBookID: sourceBookID}}
	detail.Title = readField(doc.Selection, rule.Detail.Fields["title"])
	detail.Author = readField(doc.Selection, rule.Detail.Fields["author"])
	detail.Description = readField(doc.Selection, rule.Detail.Fields["description"])
	detail.CoverURL = readAttr(doc.Selection, rule.Detail.Fields["cover_url"], "src")
	doc.Find(rule.Detail.ChapterListSelector).Each(func(i int, sel *goquery.Selection) {
		href, _ := sel.Attr("href")
		detail.Chapters = append(detail.Chapters, ChapterItem{Index: i, Title: strings.TrimSpace(sel.Text()), URL: resolveURL(bookURL, href)})
	})
	detail.ChapterCount = len(detail.Chapters)
	return detail, nil
}

func GetChapterContent(sourceID uint, sourceBookID, chapterURL string) (string, error) {
	var src models.BookSource
	if err := database.DB.First(&src, sourceID).Error; err != nil {
		return "", err
	}
	var rule SourceRule
	if err := json.Unmarshal([]byte(src.RuleJSON), &rule); err != nil {
		return "", err
	}
	body, err := fetchHTML(resolveURL(src.BaseURL, chapterURL))
	if err != nil {
		return "", err
	}
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(body))
	if err != nil {
		return "", err
	}
	content := doc.Find(rule.Chapter.ContentSelector).Text()
	for _, sel := range rule.Chapter.RemoveSelectors {
		doc.Find(sel).Remove()
	}
	content = strings.TrimSpace(content)
	content = strings.ReplaceAll(content, "\u00a0", " ")
	content = strings.Join(strings.FieldsFunc(content, func(r rune) bool { return unicode.IsSpace(r) }), " ")
	return content, nil
}

func fetchHTML(rawURL string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 PureReader")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("http status %d", resp.StatusCode)
	}
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	if utf8.Valid(data) {
		return string(data), nil
	}
	reader := transform.NewReader(bytes.NewReader(data), simplifiedchinese.GBK.NewDecoder())
	decoded, err := io.ReadAll(reader)
	if err != nil {
		return "", err
	}
	return string(decoded), nil
}

func dedupeResults(items []SearchResult) []SearchResult {
	seen := map[string]bool{}
	out := make([]SearchResult, 0, len(items))
	for _, it := range items {
		key := strings.ToLower(strings.TrimSpace(it.Title + "+" + it.Author))
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, it)
	}
	return out
}

func resolveURL(baseURL, maybeRelative string) string {
	if maybeRelative == "" {
		return ""
	}
	if strings.HasPrefix(maybeRelative, "http://") || strings.HasPrefix(maybeRelative, "https://") {
		return maybeRelative
	}
	if strings.HasPrefix(maybeRelative, "//") {
		return "https:" + maybeRelative
	}
	base, err := url.Parse(baseURL)
	if err != nil {
		return maybeRelative
	}
	ref, err := url.Parse(maybeRelative)
	if err != nil {
		return maybeRelative
	}
	return base.ResolveReference(ref).String()
}

func readField(sel *goquery.Selection, selector string) string {
	if strings.TrimSpace(selector) == "" {
		return ""
	}
	return strings.TrimSpace(sel.Find(selector).First().Text())
}

func readAttr(sel *goquery.Selection, selector, attr string) string {
	if strings.TrimSpace(selector) == "" {
		return ""
	}
	val, _ := sel.Find(selector).First().Attr(attr)
	return strings.TrimSpace(val)
}

func ImportBook(sourceID uint, sourceBookID string) (*models.Book, error) {
	detail, err := GetBookDetail(sourceID, sourceBookID)
	if err != nil {
		return nil, fmt.Errorf("get book detail: %w", err)
	}

	title := sanitizeFilename(detail.Title)
	if title == "" {
		return nil, fmt.Errorf("empty book title after sanitization")
	}

	// 跳过已存在的同名书籍
	var existing models.Book
	if err := database.DB.Where("title = ?", detail.Title).First(&existing).Error; err == nil {
		return &existing, nil
	}

	// 创建本地存储目录
	dir := filepath.Join("books_storage", title)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("create directory: %w", err)
	}

	combinedPath := filepath.Join(dir, title+".txt")
	var combinedContent strings.Builder

	for _, ch := range detail.Chapters {
		content, err := GetChapterContent(sourceID, sourceBookID, ch.URL)
		if err != nil {
			content = fmt.Sprintf("[获取章节失败: %v]", err)
		}

		chapterFilename := fmt.Sprintf("%d_%s.txt", ch.Index, sanitizeFilename(ch.Title))
		chapterPath := filepath.Join(dir, chapterFilename)
		if err := os.WriteFile(chapterPath, []byte(content), 0644); err != nil {
			return nil, fmt.Errorf("write chapter file %s: %w", chapterFilename, err)
		}

		combinedContent.WriteString(ch.Title)
		combinedContent.WriteString("\n\n")
		combinedContent.WriteString(content)
		combinedContent.WriteString("\n\n")

		// 延迟 100-200ms，避免被反爬
		time.Sleep(time.Duration(100+ch.Index%100) * time.Millisecond)
	}

	if err := os.WriteFile(combinedPath, []byte(combinedContent.String()), 0644); err != nil {
		return nil, fmt.Errorf("write combined file: %w", err)
	}

	book := &models.Book{
		Title:       detail.Title,
		Author:      detail.Author,
		FilePath:    combinedPath,
		Format:      "txt",
		StorageType: "local",
	}
	if err := database.DB.Create(book).Error; err != nil {
		return nil, fmt.Errorf("save book to database: %w", err)
	}

	return book, nil
}

func sanitizeFilename(name string) string {
	// 替换文件名中的非法字符
	replacer := strings.NewReplacer(
		"/", "_", "\\", "_", ":", "_", "*", "_",
		"?", "_", "\"", "_", "<", "_", ">", "_", "|", "_",
	)
	return replacer.Replace(strings.TrimSpace(name))
}

func NormalizeText(s string) string { return strings.Join(strings.Fields(s), " ") }

func JoinURL(base string, elems ...string) string { return path.Join(append([]string{base}, elems...)...) }

func ExtractChapterFromContent(content string, index int) (string, string, error) {
	parts := strings.Split(content, "\n\n")
	if index+1 >= len(parts) {
		return "", "", fmt.Errorf("chapter index %d out of range (total parts: %d)", index, len(parts)-1)
	}
	block := parts[index+1]
	firstNewline := strings.Index(block, "\n")
	if firstNewline < 0 {
		return "", block, nil
	}
	title := block[:firstNewline]
	chapterContent := block[firstNewline+1:]
	return chapterContent, title, nil
}
