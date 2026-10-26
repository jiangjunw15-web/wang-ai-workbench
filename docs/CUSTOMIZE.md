# 定制 CUSTOMIZE

所有定制都是**幂等脚本**，可重复执行；被改动的构建产物自动备份，可回滚。

## 品牌（Logo / 名称 / 字标）

- `brand/make_logos.py`、`brand/make_ico.py`：从内置矢量描述生成 PNG/ICO。改配色/图形后重跑。
- `brand/wang-wordmark.svg`、`brand/logo.svg`：字标与徽标源文件。
- 名称/描述/外链抹除：`brand/patch_brand.py`（字符串映射表，可直接编辑）。

## 主题色

- `brand/theme_tokens.py`：把 shadcn 设计令牌（HSL 三元组）改写为目标色板。
  亮/暗双主题都覆盖。改 `PALETTE` 字典即可换色。

## 中文 / 任意语言

- `brand/zh-cn.json` + `brand/patch_bundle.py`：构建产物级文案替换。
  要换语言，编辑 json 后重跑 `patch_bundle.py`。

## 侧边栏 / 免费化

- `brand/patch_sidebar.py`：注入自有入口、移除 Marketplace、中和付费文案。
- `brand/patch_free.py`：移除遥测端点、Cookie 同意、付费引导。

## 应用顺序

```bash
bash brand/apply.sh     # 主题 → 品牌 → 侧边栏/免费 → 缓存bust → nginx → 重启
```

## LLM 网关模型

- `platform/magpie-models.example.json` → 复制为 `magpie-models.json`，填你网关的模型；
  `platform/patch_magpie.py` 会据此生成目录条目与枚举成员。
