package services

import "strings"

var categorizerSeparators = []string{" ", "-", "_", "《", "》", "(", ")", "[", "]", "—", "·", "·", "：", ":", "（", "）", "【", "】", "，", ","}

type CategoryRule struct {
	Name     string
	Keywords []string
}

// Categorizer implements a keyword-based book title categorization engine.
type Categorizer struct {
	rules []CategoryRule
}

func NewCategorizer() *Categorizer {
	return &Categorizer{rules: defaultCategorizerRules()}
}

func (c *Categorizer) Categorize(bookTitle string) string {
	if c == nil {
		return "其他"
	}

	title := strings.ToLower(strings.TrimSpace(bookTitle))
	if title == "" {
		return "其他"
	}

	_ = splitTitle(title)

	bestCategory := "其他"
	bestMatches := 0

	for _, rule := range c.rules {
		matches := 0
		for _, keyword := range rule.Keywords {
			if keyword == "" {
				continue
			}
			if strings.Contains(title, strings.ToLower(keyword)) {
				matches++
			}
		}

		if matches > bestMatches {
			bestMatches = matches
			bestCategory = rule.Name
		}
	}

	if bestMatches == 0 {
		return "其他"
	}

	return bestCategory
}

func splitTitle(title string) []string {
	parts := []string{title}
	for _, sep := range categorizerSeparators {
		var next []string
		for _, part := range parts {
			next = append(next, strings.Split(part, sep)...)
		}
		parts = next
	}
	return parts
}

func defaultCategorizerRules() []CategoryRule {
	return []CategoryRule{
		{Name: "人妻少妇", Keywords: []string{"人妻", "少妇", "熟女", "邻家", "寂寞", "美妇", "娇妻", "出轨", "偷情", "红杏", "绿帽", "NTR", "ntr", "嫂子", "婶婶", "阿姨", "岳母", "丈母", "继母", "后妈"}},
		{Name: "校园青春", Keywords: []string{"校园", "青春", "同学", "同桌", "学姐", "学妹", "学长", "学弟", "老师", "教室", "宿舍", "校花", "班花", "大学", "高中", "初中", "学生", "班长"}},
		{Name: "乱伦家庭", Keywords: []string{"乱伦", "乱", "母", "妈", "姐", "妹", "哥", "弟", "父", "女", "儿", "子", "血缘", "近亲", "家庭", "禁忌", "不伦", "公公", "儿媳"}},
		{Name: "都市激情", Keywords: []string{"都市", "激情", "艳遇", "邂逅", "酒吧", "KTV", "酒店", "办公室", "职场", "OL", "秘书", "老板", "总裁", "白领", "电梯", "停车场", "健身房", "游泳"}},
		{Name: "古风言情", Keywords: []string{"古风", "古代", "宫", "皇", "帝", "王爷", "将军", "武林", "江湖", "侠", "仙", "妖", "魔", "神", "修真", "练气", "金丹", "元婴", "穿越", "重生", "架空", "朝代"}},
		{Name: "玄幻仙侠", Keywords: []string{"玄幻", "仙侠", "修仙", "修真", "渡劫", "飞升", "天劫", "灵根", "丹药", "法宝", "秘境", "宗门", "魔族", "妖族", "巫族", "阵法", "天书", "功法"}},
		{Name: "变态凌辱", Keywords: []string{"凌辱", "调教", "SM", "sm", "捆绑", "调", "奴", "奴役", "圈养", "虐待", "蹂躏", "羞耻", "暴露", "强制", "胁迫", "掌控", "支配", "服从", "M男", "S女", "S男", "M女"}},
		{Name: "纯爱甜文", Keywords: []string{"纯爱", "甜", "宠", "恋爱", "浪漫", "温馨", "甜蜜", "治愈", "暖", "单女主", "纯情", "初恋", "一见钟情", "日久生情", "双向奔赴", "青梅竹马"}},
		{Name: "后宫种马", Keywords: []string{"后宫", "种马", "多女", "一女多男", "NP", "np", "收", "全收", "推土机", "修罗场", "妻妾", "三妻四妾", "佳丽", "群芳", "众多美女"}},
		{Name: "异能科幻", Keywords: []string{"异能", "科幻", "末世", "丧尸", "系统", "游戏", "VR", "虚拟", "末日", "超能力", "基因", "进化", "变异", "星际", "太空", "宇宙", "机甲", "机械", "AI", "克隆"}},
		{Name: "制服角色", Keywords: []string{"制服", "护士", "空姐", "教师", "警察", "女警", "军", "特种兵", "保安", "外卖员", "快递员", "维修工", "家政", "保姆", "家教", "教练", "学员", "下属", "上司"}},
		{Name: "乡村田野", Keywords: []string{"乡村", "农村", "田野", "农民", "田野", "山", "高粱", "玉米", "牧场", "放牧", "种田", "耕种", "田野", "荒野", "边远", "小村", "村长", "乡亲"}},
		{Name: "豪门世家", Keywords: []string{"豪门", "世家", "千金", "霸总", "财阀", "继承", "联姻", "婚", "未婚夫", "未婚妻", "定亲", "娃娃亲", "指腹为婚", "家族", "名门", "富贵", "权势", "首富", "商业帝国"}},
	}
}
