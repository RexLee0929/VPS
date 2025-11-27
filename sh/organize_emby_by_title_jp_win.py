#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import re
import shutil
import sys
import unicodedata
from pathlib import Path
from typing import List, Optional, Set, Dict, Tuple
import xml.etree.ElementTree as ET

# ===== 年份目录识别 =====
YEAR_DIR_PATTERN = re.compile(r"^\d{4}$", re.ASCII)
def is_year_dir(p: Path) -> bool:
    return p.is_dir() and YEAR_DIR_PATTERN.match(p.name) is not None

# ===== Windows 目录名合法化（仅用于新建文件夹名） =====
WINDOWS_RESERVED_NAMES = {
    "CON","PRN","AUX","NUL",
    *(f"COM{i}" for i in range(1,10)),
    *(f"LPT{i}" for i in range(1,10)),
}
WINDOWS_ILLEGAL_CHARS = r'<>:"/\\|?*'

def normalize_unicode(s: str) -> str:
    # 统一全半角/连字符等
    return unicodedata.normalize("NFKC", s)

def sanitize_folder_name(name: str) -> str:
    name = normalize_unicode(name).strip()
    trans = {ord(c): " " for c in WINDOWS_ILLEGAL_CHARS}
    name = name.translate(trans)
    name = "".join(ch for ch in name if ch.isprintable())
    name = re.sub(r"\s+", " ", name).strip(" .")
    if not name:
        name = "Unknown"
    base = name.rstrip(". ")
    upper = base.upper()
    if upper in WINDOWS_RESERVED_NAMES or re.match(r"^(COM|LPT)\d$", upper):
        base = "_" + base
    return base[:240]

# ===== 可忽略尾缀（带数字/变体） =====
ART_TAIL = r"(?:fanart|poster|banner|landscape|thumb|clearlogo|clearart|discart|trailer)"
ART_SUFFIX_REGEX = rf"(?:[-_ ]{ART_TAIL}(?:[-_ ]?\d*)\b)"
LANG_TAIL = r"(?:chs|cht|eng|jpn|kor|sc|tc|gb|big5|forced|sdh|xlsub)"
LANG_SUFFIX_REGEX = rf"(?:\.(?:{LANG_TAIL})\b)"
IGNORE_TAIL_REGEX = re.compile(rf"({ART_SUFFIX_REGEX}|{LANG_SUFFIX_REGEX})$", re.IGNORECASE)

def strip_ignored_tails(stem: str) -> str:
    s = stem
    while True:
        m = IGNORE_TAIL_REGEX.search(s)
        if not m:
            return s
        s = s[:m.start()]

# ===== 媒体相关扩展名 =====
MEDIA_EXTS = {
    # 视频
    "mkv", "mp4", "avi", "mov", "m4v", "ts", "m2ts", "webm", "wmv",
    # 音频
    "flac", "aac", "mp3", "mka", "dts", "ac3", "eac3", "wav",
    # 字幕/章节
    "srt", "ass", "ssa", "sup", "vtt", "sub", "idx", "pgs", "chapters",
    # 元数据/NFO
    "nfo",
    # 图片/海报/封面
    "jpg", "jpeg", "png", "webp", "tbn",
    # 附属
    "nfo_orig", "txt", "xml"
}

def file_is_media_related(p: Path) -> bool:
    return p.suffix.lower().lstrip(".") in MEDIA_EXTS

def list_top_level_files(dir_path: Path) -> List[Path]:
    return [f for f in dir_path.iterdir() if f.is_file()]

# ===== 解析 <title_jp>（稳健） =====
def parse_title_jp_from_nfo(nfo_path: Path) -> Optional[str]:
    try:
        text = nfo_path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return None
    # 尽量容错 XML
    try:
        filtered = "".join(ch for ch in text if ch in ("\t","\n","\r") or ch >= " ")
        root = ET.fromstring(filtered)
    except Exception:
        # 正则直抓
        for tag in ("title_jp", "title"):
            m = re.search(rf"<\s*{tag}\s*>(.*?)</\s*{tag}\s*>", text, flags=re.IGNORECASE | re.DOTALL)
            if m:
                return sanitize_folder_name(m.group(1).strip())
        return None

    def find_text(tag: str) -> Optional[str]:
        el = root.find(tag)
        if el is not None and (el.text or "").strip():
            return sanitize_folder_name(el.text.strip())
        for child in root.iter():
            if str(child.tag).lower() == tag.lower():
                if child.text and child.text.strip():
                    return sanitize_folder_name(child.text.strip())
        return None

    return find_text("title_jp") or find_text("title")

# ===== 方括号编号与分卷/话次键抽取 =====
BRACKET_TOKEN_RE = re.compile(r"\[(.*?)\]")

# 支持：Vol.1/Vol 1、第1话/第2話、Ⅰ/Ⅱ/III/IV/V…、D1-1/D1-2、第一夜/第二夜、第一巻/第二巻 等
ROMAN_MAP = {
    "Ⅰ":1,"Ⅱ":2,"Ⅲ":3,"Ⅳ":4,"Ⅴ":5,"Ⅵ":6,"Ⅶ":7,"Ⅷ":8,"Ⅸ":9,"Ⅹ":10,
    "I":1,"II":2,"III":3,"IV":4,"V":5,"VI":6,"VII":7,"VIII":8,"IX":9,"X":10,
}
def roman_to_int(s: str) -> Optional[int]:
    s = s.upper()
    return ROMAN_MAP.get(s)

EPISODE_PATTERNS = [
    re.compile(r"\bvol[.\s_-]*(\d+)\b", re.IGNORECASE),
    re.compile(r"第\s*(\d+)\s*[话話集巻]", re.IGNORECASE),
    re.compile(r"\bD\s*([0-9]+)\s*-\s*([0-9]+)\b", re.IGNORECASE),  # D1-1
    re.compile(r"(?:第\s*(一|二|三|四|五|六|七|八|九|十)\s*[夜巻])"),
    re.compile(r"\b(Ⅰ|Ⅱ|Ⅲ|Ⅳ|Ⅴ|Ⅵ|Ⅶ|Ⅷ|Ⅸ|Ⅹ|I|II|III|IV|V|VI|VII|VIII|IX|X)\b"),
]

KANJI_NUM = {"一":1,"二":2,"三":3,"四":4,"五":5,"六":6,"七":7,"八":8,"九":9,"十":10}

def extract_bracket_tokens(name: str) -> List[str]:
    tokens = []
    for m in BRACKET_TOKEN_RE.finditer(name):
        t = m.group(1).strip()
        t = re.sub(r"\s+", "", t)
        if re.match(r"^[A-Za-z0-9\-_.]+$", t) and len(t) >= 3:
            tokens.append(t.upper())
    return tokens

def extract_episode_key(name: str) -> Optional[str]:
    base = strip_ignored_tails(Path(name).stem)
    s = normalize_unicode(base)

    # D1-1 形式优先
    m = EPISODE_PATTERNS[2].search(s)
    if m:
        return f"D{int(m.group(1))}-{int(m.group(2))}"

    # Vol.N
    m = EPISODE_PATTERNS[0].search(s)
    if m:
        return f"VOL-{int(m.group(1))}"

    # 第N话/話/集/巻
    m = EPISODE_PATTERNS[1].search(s)
    if m:
        return f"EP-{int(m.group(1))}"

    # 第一夜/第二夜、第一巻/第二巻
    m = EPISODE_PATTERNS[3].search(s)
    if m:
        return f"KANJI-{KANJI_NUM.get(m.group(1), 0)}"

    # 罗马数字
    m = EPISODE_PATTERNS[4].search(s)
    if m:
        x = roman_to_int(m.group(1))
        if x:
            return f"ROM-{x}"

    return None

# ===== 严禁改名移动（冲突仅跳过） =====
def safe_move_no_rename(src: Path, dst: Path, dry_run: bool = False) -> bool:
    if dst.exists():
        try:
            if dst.is_file() and src.is_file() and src.stat().st_size == dst.stat().st_size:
                print(f"[SKIP] 已存在同名同大小：{dst}")
                return True
        except Exception:
            pass
        print(f"[CONFLICT] 目标已存在不同内容：{dst}，保持原位。")
        return False
    print(f"[MOVE] {src} -> {dst}")
    if not dry_run:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dst))
    return True

# ===== 预建 NFO → 目录映射，并抽取匹配锚点 =====
def build_nfo_index_and_dirs(nfo_files: List[Path], year_dir: Path) -> Tuple[Dict[Path, Dict[str, object]], Dict[Path, Path]]:
    nfo_idx: Dict[Path, Dict[str, object]] = {}
    nfo_dir: Dict[Path, Path] = {}
    seen_dirs: Set[Path] = set()

    for nfo in nfo_files:
        stem_raw = nfo.stem
        tokens = set(extract_bracket_tokens(stem_raw))
        ep_key = extract_episode_key(stem_raw)
        # 目录名：先 title_jp，然后 title，最后 stem
        title = parse_title_jp_from_nfo(nfo)
        if not title:
            title = sanitize_folder_name(strip_ignored_tails(stem_raw) or "Unknown")
        target_dir = year_dir / title

        if target_dir not in seen_dirs:
            print(f"[DIR] 目标文件夹：{target_dir}")
            seen_dirs.add(target_dir)

        nfo_idx[nfo] = {
            "tokens": tokens,
            "ep_key": ep_key,
            "stem_strict": strip_ignored_tails(stem_raw),
        }
        nfo_dir[nfo] = target_dir

    return nfo_idx, nfo_dir

# ===== 选择目标 NFO（严格且带分卷消歧） =====
def choose_target_nfo_for_file(file_path: Path, nfo_idx: Dict[Path, Dict[str, object]]) -> Optional[Path]:
    if file_path.suffix.lower() == ".nfo":
        return file_path

    f_tokens = set(extract_bracket_tokens(file_path.stem))
    f_ep = extract_episode_key(file_path.stem)
    f_stem = strip_ignored_tails(file_path.stem)

    # 必须先有 token（有编号才允许走），否则仅当完全无 token 时才走 stem 模式
    if f_tokens:
        candidates = [nfo for nfo, meta in nfo_idx.items() if meta["tokens"] & f_tokens]
        if len(candidates) == 1:
            return candidates[0]
        if len(candidates) > 1:
            # 用分卷/话次键消歧
            if f_ep:
                narrowed = [nfo for nfo in candidates if nfo_idx[nfo]["ep_key"] == f_ep]
                if len(narrowed) == 1:
                    return narrowed[0]
            # 再尝试严格 stem（只在多候选时，用于完全一致的情况）
            narrowed = [nfo for nfo in candidates if nfo_idx[nfo]["stem_strict"] == f_stem]
            if len(narrowed) == 1:
                return narrowed[0]
            return None
        return None

    # 无 token：仅允许严格 stem 唯一匹配
    candidates = [nfo for nfo, meta in nfo_idx.items() if meta["stem_strict"] == f_stem]
    if len(candidates) == 1:
        return candidates[0]
    return None

# ===== 主流程 =====
def organize_year_dir(year_dir: Path, dry_run: bool = False) -> Tuple[int,int,int,int]:
    print(f"\n==== 处理年份目录：{year_dir} ====")
    files = list_top_level_files(year_dir)
    nfo_files = [p for p in files if p.suffix.lower() == ".nfo"]
    if not nfo_files:
        print("[INFO] 未发现 NFO，跳过该年份。")
        return (0,0,0,0)

    nfo_idx, nfo_dir = build_nfo_index_and_dirs(nfo_files, year_dir)

    folders_created = len(set(nfo_dir.values()))
    moved = conflict = skipped = 0

    for f in files:
        if not file_is_media_related(f):
            continue
        target_nfo = choose_target_nfo_for_file(f, nfo_idx)
        if target_nfo is None:
            print(f"[SKIP] 无唯一匹配 NFO：{f.name}")
            skipped += 1
            continue
        dest = nfo_dir[target_nfo] / f.name
        ok = safe_move_no_rename(f, dest, dry_run=dry_run)
        if ok:
            moved += 1
        else:
            conflict += 1

    return (folders_created, moved, conflict, skipped)

def scan_root_and_organize(root: Path, years: Optional[List[str]], dry_run: bool) -> None:
    if not root.exists() or not root.is_dir():
        print(f"[ERROR] 根目录不存在或不是目录：{root}")
        sys.exit(2)

    year_dirs = [p for p in root.iterdir() if is_year_dir(p)]
    if years:
        years_set = set(years)
        year_dirs = [p for p in year_dirs if p.name in years_set]
    if not year_dirs:
        if years:
            print(f"[WARN] 指定年份未找到：{', '.join(years)}")
        else:
            print("[WARN] 根目录下未找到任何四位数字年份目录。")
        return

    total_dirs = total_moved = total_conflict = total_skipped = 0
    for yd in sorted(year_dirs, key=lambda x: x.name):
        d, m, c, s = organize_year_dir(yd, dry_run=dry_run)
        total_dirs += d
        total_moved += m
        total_conflict += c
        total_skipped += s

    print("\n==== 汇总 ====")
    print(f"新建（或将使用）文件夹数：{total_dirs}")
    print(f"成功移动文件数：{total_moved}")
    print(f"冲突（同名不同内容，已跳过）数：{total_conflict}")
    print(f"跳过（无唯一匹配 NFO）数：{total_skipped}")

def main():
    parser = argparse.ArgumentParser(
        description="Windows 11（超严格版）：仅在编号命中且分卷/话次唯一消歧（必要时再比对严格 stem）时移动到 NFO 的 <title_jp> 目录；绝不改名。"
    )
    parser.add_argument("--root", required=True, help="媒体库根目录，如 F:\\ONEDRIVE\\...\\HENTAI")
    parser.add_argument("--year", action="append", help="仅处理指定年份（可多次传入）")
    parser.add_argument("--dry-run", action="store_true", help="预演模式：只打印操作，不实际移动")
    args = parser.parse_args()

    root = Path(args.root)
    print(f"[START] 根目录：{root} | dry-run: {args.dry_run}")
    if args.year:
        print(f"[START] 仅处理年份：{', '.join(args.year)}")

    scan_root_and_organize(root, args.year, dry_run=args.dry_run)
    print("[DONE] 处理完成。")

if __name__ == "__main__":
    main()
