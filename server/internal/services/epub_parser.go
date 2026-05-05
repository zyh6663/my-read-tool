package services

import (
	"archive/zip"
	"encoding/xml"
	"fmt"
	"io"
	"path/filepath"
	"regexp"
	"strings"
)

// ============================================================================
// EpubParser — BookParser 接口实现
// ============================================================================

// EpubParser 是 EPUB 格式的解析器。
// 使用 Go 标准库 archive/zip 和 encoding/xml，无需第三方 epub 库。
type EpubParser struct{}

// SupportedFormats 返回支持的扩展名列表。
func (p *EpubParser) SupportedFormats() []string {
	return []string{"epub"}
}

// Parse 实现 BookParser 接口，解析 EPUB 文件。
func (p *EpubParser) Parse(filePath string) (*ParsedBook, error) {
	reader, err := zip.OpenReader(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open epub file: %w", err)
	}
	defer reader.Close()

	// 1. 定位并解析 container.xml 获取 OPF 路径
	opfPath, err := findOPFPath(reader)
	if err != nil {
		return nil, fmt.Errorf("failed to locate OPF: %w", err)
	}

	// 2. 解析 OPF 获取元数据和 spine 顺序
	opf, err := parseOPF(reader, opfPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse OPF: %w", err)
	}

	// 3. 计算 OPF 所在的基准目录
	baseDir := filepath.Dir(opfPath)

	// 4. 按 spine 顺序提取 HTML/XHTML 章节内容
	chapters := extractChapters(reader, baseDir, opf)

	// 5. 构建元数据
	metadata := map[string]string{
		"format":     "epub",
		"language":   opf.Language,
		"publisher":  opf.Publisher,
		"identifier": opf.Identifier,
	}
	if opf.Creator != "" {
		metadata["creator"] = opf.Creator
	}

	title := opf.Title
	if title == "" {
		title = strings.TrimSuffix(filepath.Base(filePath), filepath.Ext(filePath))
	}

	return &ParsedBook{
		Title:    title,
		Author:   opf.Creator,
		Chapters: chapters,
		Metadata: metadata,
	}, nil
}

// init 自动注册 EpubParser 到全局解析器工厂。
func init() {
	RegisterParser(&EpubParser{})
}

// ============================================================================
// EPUB 内部解析结构
// ============================================================================

// container XML 结构
type containerXML struct {
	XMLName   xml.Name          `xml:"container"`
	RootFiles []rootFileElement `xml:"rootfiles>rootfile"`
}

type rootFileElement struct {
	FullPath string `xml:"full-path,attr"`
}

// OPF (package) XML 结构 — 只提取我们关心的字段
type opfPackage struct {
	XMLName  xml.Name    `xml:"package"`
	Metadata opfMetadata `xml:"metadata"`
	Spine    opfSpine    `xml:"spine"`
	Manifest opfManifest `xml:"manifest"`
}

type opfMetadata struct {
	Title      string `xml:"title"`
	Creator    string `xml:"creator"`
	Language   string `xml:"language"`
	Publisher  string `xml:"publisher"`
	Identifier string `xml:"identifier"`
}

type opfSpine struct {
	ItemRefs []opfItemRef `xml:"itemref"`
}

type opfItemRef struct {
	IDRef string `xml:"idref,attr"`
}

type opfManifest struct {
	Items []opfItem `xml:"item"`
}

type opfItem struct {
	ID        string `xml:"id,attr"`
	Href      string `xml:"href,attr"`
	MediaType string `xml:"media-type,attr"`
}

// parsedOPF 解析后的 OPF 结果
type parsedOPF struct {
	Title      string
	Creator    string
	Language   string
	Publisher  string
	Identifier string
	Spine      []string  // 按 spine 顺序的 idref 列表
	Manifest   []opfItem // manifest 条目列表
}

// ============================================================================
// 辅助函数
// ============================================================================

// findOPFPath 在 EPUB zip 中定位 META-INF/container.xml，读取 OPF 路径。
func findOPFPath(reader *zip.ReadCloser) (string, error) {
	for _, f := range reader.File {
		if f.Name == "META-INF/container.xml" {
			rc, err := f.Open()
			if err != nil {
				return "", err
			}
			defer rc.Close()

			var container containerXML
			data, err := io.ReadAll(rc)
			if err != nil {
				return "", err
			}
			if err := xml.Unmarshal(data, &container); err != nil {
				return "", err
			}
			if len(container.RootFiles) == 0 {
				return "", fmt.Errorf("no rootfile in container.xml")
			}
			return container.RootFiles[0].FullPath, nil
		}
	}
	return "", fmt.Errorf("META-INF/container.xml not found in epub")
}

// parseOPF 解析 OPF 文件并提取元数据和 spine。
func parseOPF(reader *zip.ReadCloser, opfPath string) (*parsedOPF, error) {
	file, err := findFileInZip(reader, opfPath)
	if err != nil {
		return nil, err
	}

	rc, err := file.Open()
	if err != nil {
		return nil, err
	}
	defer rc.Close()

	data, err := io.ReadAll(rc)
	if err != nil {
		return nil, err
	}

	var pkg opfPackage
	if err := xml.Unmarshal(data, &pkg); err != nil {
		return nil, fmt.Errorf("invalid OPF XML: %w", err)
	}

	spineRefs := make([]string, len(pkg.Spine.ItemRefs))
	for i, ref := range pkg.Spine.ItemRefs {
		spineRefs[i] = ref.IDRef
	}

	return &parsedOPF{
		Title:      pkg.Metadata.Title,
		Creator:    pkg.Metadata.Creator,
		Language:   pkg.Metadata.Language,
		Publisher:  pkg.Metadata.Publisher,
		Identifier: pkg.Metadata.Identifier,
		Spine:      spineRefs,
		Manifest:   pkg.Manifest.Items,
	}, nil
}

// extractChapters 按 spine 顺序提取所有 HTML/XHTML 内容的纯文本。
func extractChapters(reader *zip.ReadCloser, baseDir string, opf *parsedOPF) []ParsedChapter {
	// 构建 ID -> 路径 的映射
	idToHref := make(map[string]string)
	idToMediaType := make(map[string]string)
	for _, item := range opf.Manifest {
		idToHref[item.ID] = item.Href
		idToMediaType[item.ID] = item.MediaType
	}

	var chapters []ParsedChapter
	for _, idref := range opf.Spine {
		href, ok := idToHref[idref]
		if !ok {
			continue
		}

		// 只处理 application/xhtml+xml 或 text/html
		mediaType := idToMediaType[idref]
		if mediaType != "application/xhtml+xml" && mediaType != "text/html" {
			continue
		}

		// 拼接完整路径（相对于 OPF 所在目录）
		fullPath := resolvePath(baseDir, href)

		text, title, err := extractTextFromHTML(reader, fullPath)
		if err != nil {
			// 解析失败不中断整个流程，跳过该章节
			continue
		}

		if title == "" {
			title = fmt.Sprintf("Chapter %d", len(chapters)+1)
		}

		chapters = append(chapters, ParsedChapter{
			Index:   len(chapters),
			Title:   title,
			Content: text,
		})
	}

	return chapters
}

// extractTextFromHTML 从 ZIP 中读取 HTML 文件，提取纯文本和标题。
func extractTextFromHTML(reader *zip.ReadCloser, filePath string) (text string, title string, err error) {
	file, err := findFileInZip(reader, filePath)
	if err != nil {
		return "", "", err
	}

	rc, err := file.Open()
	if err != nil {
		return "", "", err
	}
	defer rc.Close()

	data, err := io.ReadAll(rc)
	if err != nil {
		return "", "", err
	}

	htmlStr := string(data)

	// 提取 <title>
	titleRe := regexp.MustCompile(`(?is)<title[^>]*>(.*?)</title>`)
	if m := titleRe.FindStringSubmatch(htmlStr); m != nil {
		title = strings.TrimSpace(m[1])
	}

	// 移除所有标签，保留纯文本
	text = stripTags(htmlStr)

	// 规范化空白
	text = regexp.MustCompile(`\n{3,}`).ReplaceAllString(text, "\n\n")
	text = strings.TrimSpace(text)

	return text, title, nil
}

// buildHTMLEntity 通过 rune 拼接的方式构造 HTML 实体字符串，
// 避免在源代码中使用字面量 & 导致编辑器自动格式化破坏代码。
func buildHTMLEntity(name string) string {
	return "\u0026" + name + ";"
}

// htmlEntityReplacements 返回 HTML 实体 -> 替换字符的映射表。
// 使用函数延迟构造，彻底避免源代码中出现 &xxx; 字面量。
func htmlEntityReplacements() map[string]string {
	return map[string]string{
		buildHTMLEntity("nbsp"):  " ",
		buildHTMLEntity("quot"):  "\u0022",
		buildHTMLEntity("amp"):   "\u0026",
		buildHTMLEntity("lt"):    "\u003c",
		buildHTMLEntity("gt"):    "\u003e",
		buildHTMLEntity("#39"):   "'",
	}
}

// stripTags 从 HTML 字符串中移除所有标签。
func stripTags(html string) string {
	// 先移除 script/style 标签及其内容
	scriptRe := regexp.MustCompile(`(?is)<script[^>]*>.*?</script>`)
	styleRe := regexp.MustCompile(`(?is)<style[^>]*>.*?</style>`)
	html = scriptRe.ReplaceAllString(html, "")
	html = styleRe.ReplaceAllString(html, "")

	// 将块级标签替换为换行
	blockRe := regexp.MustCompile(`(?i)</?(div|p|br|h[1-6]|li|tr)[^>]*/?>`)
	html = blockRe.ReplaceAllString(html, "\n")

	// 移除所有剩余的标签
	tagRe := regexp.MustCompile(`<[^>]*>`)
	html = tagRe.ReplaceAllString(html, "")

	// 解码常见实体
	for entity, replacement := range htmlEntityReplacements() {
		html = strings.ReplaceAll(html, entity, replacement)
	}

	// 清理多余空白
	spaceRe := regexp.MustCompile(`[ \t]+`)
	html = spaceRe.ReplaceAllString(html, " ")

	return html
}

// findFileInZip 在 ZIP 中查找指定路径的文件（精确匹配）。
func findFileInZip(reader *zip.ReadCloser, target string) (*zip.File, error) {
	for _, f := range reader.File {
		if f.Name == target {
			return f, nil
		}
	}
	return nil, fmt.Errorf("file not found in epub: %s", target)
}

// resolvePath 拼接基准目录和相对路径，处理路径编码。
func resolvePath(baseDir, href string) string {
	if baseDir == "." || baseDir == "" {
		return href
	}

	// 解码 URL 编码
	href = strings.ReplaceAll(href, "%20", " ")

	// 路径拼接
	fullPath := filepath.Join(baseDir, href)

	// 标准化路径分隔符为 /
	fullPath = strings.ReplaceAll(fullPath, `\`, "/")

	return fullPath
}