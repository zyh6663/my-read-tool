package services

import (
	"os"
	"testing"
)

func TestParseTXTFile(t *testing.T) {
	// Create a temporary test file
	content := `三体

第一章 科学边界

汪淼感到自己确实是一个死人。

这是汪淼第一次见到史强。

第二章 三体问题

汪淼和史强在作战中心。

夜晚很安静。

第三章 红岸基地

叶文洁在红岸基地工作。

这是一个重要的章节。

后记

这本书到此结束。`
	tmpFile, err := os.CreateTemp("", "test_*.txt")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(content); err != nil {
		t.Fatal(err)
	}
	tmpFile.Close()

	chapters, toc, err := ParseTXTFile(tmpFile.Name())
	if err != nil {
		t.Fatal(err)
	}

	if len(chapters) != 4 {
		t.Fatalf("expected 4 chapters, got %d", len(chapters))
	}

	// First chapter (前言/foreword)
	if chapters[0].Title != "前言" {
		t.Errorf("expected first chapter title '前言', got '%s'", chapters[0].Title)
	}
	if chapters[0].Content == "" {
		t.Error("expected first chapter to have content")
	}

	// Second chapter (第一章)
	if chapters[1].Title != "第一章 科学边界" {
		t.Errorf("expected '第一章 科学边界', got '%s'", chapters[1].Title)
	}
	if chapters[1].Content != "汪淼感到自己确实是一个死人。" {
		t.Errorf("unexpected content: %s", chapters[1].Content)
	}

	// Check TOC
	if len(toc) != 4 {
		t.Fatalf("expected 4 TOC entries, got %d", len(toc))
	}
	if toc[1].Title != "第一章 科学边界" {
		t.Errorf("expected TOC[1] '第一章 科学边界', got '%s'", toc[1].Title)
	}
}
