#!/usr/bin/env python3
"""Mirrors Pornhub/PHParser.swift against saved site fixtures.

The Swift parser is compiled in CI. This script keeps the same assertions
runnable here, where swiftc is not installed.
"""
import json, re, sys
from html import unescape
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else "Tests/Fixtures")

def clean(value):
    text = unescape(value or "")
    text = text.replace("\\/", "/")
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()

def videos(html):
    items = []
    for m in re.finditer(r"<li\b[^>]*data-video-vkey=\"([^\"]+)\"[^>]*>.*?</li>", html, re.S):
        block = m.group(0)
        title = clean(re.search(r'class="thumbnailTitle"[^>]*>(.*?)</a>', block, re.S).group(1)) if re.search(r'class="thumbnailTitle"', block) else clean(re.search(r'alt="([^"]+)"', block).group(1) if re.search(r'alt="', block) else "")
        if not title:
            continue
        author = clean(re.search(r'<a class="uploaderLink"[^>]*>(.*?)</a>', block, re.S).group(1)) if "uploaderLink" in block else ""
        duration = clean(re.search(r'class="[^"]*\btime\b[^"]*"[^>]*>([^<]+)', block).group(1)) if re.search(r'class="[^"]*\btime\b', block) else ""
        items.append({"vkey": m.group(1), "title": title, "author": author, "duration": duration, "verified": "badge-verified" in block or "hasBadge" in block})
    return items

home = (root / "home.html").read_text(errors="ignore")
vs = videos(home)
assert len(vs) >= 20, len(vs)
assert vs[0]["vkey"] == "6ac27ce22fb52", vs[0]
assert vs[0]["author"] == "Delsa jooon", vs[0]
assert vs[0]["duration"] == "11:39", vs[0]
assert vs[0]["verified"]
chips = re.findall(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', home[home.find("trendingNowWrapper"):home.find("trendingNowWrapper")+12000], re.S)
chip_titles = [clean(inner) for _, inner in chips if clean(inner)]
assert chip_titles[0] == "Shorties", chip_titles[:3]
assert "欧美" in chip_titles

search = (root / "search.html").read_text(errors="ignore")
sv = videos(search)
assert len(sv) == 30, len(sv)
pages = {int(x) for x in re.findall(r"(?:[?&]|&amp;)page=(\d+)", search)}
assert 2 in pages

video = (root / "video.html").read_text(errors="ignore")
start = video.find("{", video.find("var flashvars_"))
depth = 0
end = None
for i, ch in enumerate(video[start:], start):
    depth += ch == "{"
    depth -= ch == "}"
    if depth == 0:
        end = i + 1
        break
blob = json.loads(video[start:end])
hls = [d for d in blob["mediaDefinitions"] if d.get("format") == "hls" and d.get("videoUrl")]
assert {d["quality"] for d in hls} >= {"1080", "720", "480", "240"}
assert blob["video_duration"] == 699
assert "劲爆重口味" in video
assert "41.7K" in video or "41.3K" in video

related = json.loads((root / "related.json").read_text())
count = sum(len(related[k]) for k in ("related", "more", "mostViewed", "topRated"))
assert count >= 40, count

cats = (root / "cats.html").read_text(errors="ignore")
blocks = re.findall(r'<li class="catPic" data-category="(\d+)">(.*?)</li>', cats, re.S)
assert len(blocks) >= 100, len(blocks)
assert clean(re.search(r"<strong>([^<]+)</strong>", blocks[0][1]).group(1)) == "熟女"

stars = (root / "stars.html").read_text(errors="ignore")
assert "johnny-sins" in stars.lower() or "Johnny" in stars

gifs = (root / "gifs.html").read_text(errors="ignore")
assert gifs.count("/gif/") >= 10
assert "data-gif-url" in gifs

albums = (root / "albums.html").read_text(errors="ignore")
assert albums.count("/album/") >= 10

playlists = (root / "playlists.html").read_text(errors="ignore")
assert "/playlist/109018181" in playlists

chunk = (root / "playlist-chunk.html").read_text(errors="ignore")
chunk_keys = re.findall(r"viewkey=([A-Za-z0-9]+)", chunk)
assert len(set(chunk_keys)) >= 5, len(set(chunk_keys))

print(f"ok videos={len(vs)} search={len(sv)} hls={len(hls)} related={count} cats={len(blocks)}")
