-- imports
import("devel.git")

function mtime(file)
    return os.date("%Y-%m-%dT%H:%M:%S+08:00", os.mtime(file))
end

function header(url)
    return format([[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>xrepo</title>
  <link rel="icon" href="/assets/img/favicon.ico">
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
  <meta name="description" content="Description">
  <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">
  <link href="//cdn.jsdelivr.net/npm/github-markdown-css@4.0.0/github-markdown.min.css" rel="stylesheet">
  <style>
	.markdown-body {
		box-sizing: border-box;
		min-width: 200px;
		max-width: 980px;
		margin: 0 auto;
		padding: 45px;
	}

	@media (max-width: 767px) {
		.markdown-body {
			padding: 15px;
		}
	}
  </style>
</head>
<body>
<article class="markdown-body">
<h4>This is a mirror page, please see the original page: </h4><a href="%s">%s</a>
</br>
    ]], url, url)
end

function tailer()
    return [[
</article>
</body>
</html>]]
end

function ads()
    return [[
<script async type="text/javascript" src="//cdn.carbonads.com/carbon.js?serve=CE7I52QU&placement=xmakeio" id="_carbonads_js"></script>
<style>
#carbonads {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu,
  Cantarell, "Helvetica Neue", Helvetica, Arial, sans-serif;
}

#carbonads {
  display: flex;
  max-width: 330px;
  background-color: hsl(0, 0%, 98%);
  box-shadow: 0 1px 4px 1px hsla(0, 0%, 0%, .1);
}

#carbonads a {
  color: inherit;
  text-decoration: none;
}

#carbonads a:hover {
  color: inherit;
}

#carbonads span {
  position: relative;
  display: block;
  overflow: hidden;
}

#carbonads .carbon-wrap {
  display: flex;
}

.carbon-img {
  display: block;
  margin: 0;
  line-height: 1;
}

.carbon-img img {
  display: block;
}

.carbon-text {
  font-size: 13px;
  padding: 10px;
  line-height: 1.5;
  text-align: left;
}

.carbon-poweredby {
  display: block;
  padding: 8px 10px;
  background: repeating-linear-gradient(-45deg, transparent, transparent 5px, hsla(0, 0%, 0%, .025) 5px, hsla(0, 0%, 0%, .025) 10px) hsla(203, 11%, 95%, .4);
  text-align: center;
  text-transform: uppercase;
  letter-spacing: .5px;
  font-weight: 600;
  font-size: 9px;
  line-height: 1;
}
</style>
    ]]
end

-- fix links
function _fixlinks(htmldata)

    -- <a href="/manual/builtin_modules?id=osmv">os.mv</a>
    -- => <a href="/mirror/manual/builtin_modules.html#osmv">os.mv</a>
    htmldata = htmldata:gsub("(href=\"(.-)\")", function(_, href)
        if href:startswith("/") and not href:startswith("/#/") then
            local splitinfo = href:split('?', {plain = true})
            local url = splitinfo[1]
            href = "/mirror" .. url .. ".html"
            if splitinfo[2] then
                local anchor = splitinfo[2]:gsub("id=", "")
                href = href .. "#" .. anchor
            end
            print(" -> fix %s", href)
        end
        return "href=\"" .. href .. "\""
    end)

    -- <h4 id="os-rm">os.rm</h4>
    -- => <h4 id="osrm">os.rm</h4>
    htmldata = htmldata:gsub("(id=\"(.-)\")", function(_, id)
        id = id:gsub("%-", "")
        return "id=\"" .. id .. "\""
    end)
    return htmldata
end

-- generate mirror files and sitemap.xml
-- we need install https://github.com/cwjohan/markdown-to-html first
-- npm install markdown-to-html -g
--
-- Or use showdown-cli https://github.com/showdownjs/showdown
--
function build_mirror_files()
    local siteroot = "https://xrepo.xmake.io"
    local mirrordir = "mirror"
    local sitemap = io.open("sitemap.xml", 'w')
    sitemap:print([[
<?xml version="1.0" encoding="UTF-8"?>
<urlset
      xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
            http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">
    ]])
    sitemap:print([[
<url>
  <loc>%s</loc>
  <lastmod>%s</lastmod>
</url>
]], siteroot, mtime("index.html"))
    os.rm(mirrordir)
    for _, markdown in ipairs(os.files("**.md")) do
        local basename = path.basename(markdown)
        if not basename:startswith("_") then

            -- get the raw url
            if basename == "README" then
                basename = ""
            end
            local url = siteroot .. '/mirror'
            local rawurl = siteroot .. '/#'
            local dir = path.directory(markdown)
            if dir ~= '.' then
                rawurl = rawurl .. '/' .. dir
                url = url .. '/' .. dir
            end
            rawurl = rawurl .. '/' .. basename
            url = url .. '/' .. (basename == "" and "index.html" or (basename .. ".html"))

            -- generate html file
            local htmlfile = path.join(mirrordir, dir, basename == "" and "index.html" or (basename .. ".html"))
            local htmldata = os.iorunv("markdown", {markdown})
            local f = io.open(htmlfile, 'w')
            if f then
                f:write(header(rawurl))
                f:write(ads())
                htmldata = htmldata:gsub("&%a-;", function (w) 
                    local maps = {["&lt;"] = "<", ["&gt;"] = ">", ["&quot;"] = "\""}
                    return maps[w]
                end)
                f:write(_fixlinks(htmldata))
                f:write(tailer())
                f:close()
            end

            --[[
            local tmpfile = os.tmpfile()
            os.mkdir(path.directory(tmpfile))
            os.execv("showdown", {"makehtml", "-i", markdown, "-o", tmpfile})
            local f = io.open(htmlfile, 'w')
            if f then
                f:write(header(rawurl))
                f:write(ads())
                f:write(_fixlinks(io.readfile(tmpfile)))
                f:write(tailer())
                f:close()
            end
            os.rm(tmpfile)]]

            print("build %s => %s, %s", markdown, htmlfile, mtime(htmlfile))
            print("url %s -> %s", url, rawurl)

            -- generate sitemap
            sitemap:print([[
<url>
  <loc>%s</loc>
  <lastmod>%s</lastmod>
</url>
]], url, mtime(htmlfile))
        end
    end
    sitemap:print("</urlset>")
    sitemap:close()
end

-- write package
function write_package(file, pkg, plat, archs)
    local name = pkg:name()
    local homepage = pkg:get("homepage")
    local license = pkg:get("license")
    local versions = pkg:versions()
    local xmakefile = ("https://github.com/xmake-io/xmake-repo/blob/master/packages/%s/%s/xmake.lua"):format(name:sub(1, 1), name)
    file:print("### %s (%s)", name, plat)
    file:print("")
    file:print("")
    file:print("| Description | *%s* |", pkg:description())
    file:print("| -- | -- |")
    file:print("| Homepage | [%s](%s) |", homepage, homepage)
    if license then
        file:print("| License | %s |", license)
    end
    archs = table.copy(archs)
    table.sort(archs)
    table.sort(versions)
    file:print("| Versions | %s |", table.concat(versions, ", "))
    file:print("| Architectures | %s |", table.concat(archs, ", "))
    file:print("| Definition | [%s/xmake.lua](%s) |", name, xmakefile)
    file:print("")
    file:print("##### Install command")
    file:print("")
    file:print("```console")
    if plat == "android" then
        file:print("xrepo install -p android [--ndk=/xxx] %s", name)
    elseif plat == "mingw" then
        file:print("xrepo install -p mingw [--mingw=/xxx] %s", name)
    elseif plat == "iphoneos" then
        file:print("xrepo install -p iphoneos %s", name)
    elseif plat == "cross" then
        file:print("xrepo install -p cross [--sdk=/xxx] %s", name)
    else
        file:print("xrepo install %s", name)
    end
    file:print("```")
    file:print("")
    file:print("##### Integration in the project (xmake.lua)")
    file:print("")
    file:print("```lua")
    file:print("add_requires(\"%s\")", name)
    file:print("```")
    file:print("")
    file:print("")
end

-- get latest added packages
-- git -c pager.log=false log --diff-filter=A --stat --max-count=5 --format=%aD
function latest_packages()
    local latest  = {}
    local results = os.iorunv("git -c pager.log=false log --diff-filter=A --stat --max-count=5 --format=%aD")
    if results then
        for _, line in ipairs(results:split('\n', {plain = true})) do
            line = line:split('|')[1]
            line = line:trim()
            if line:endswith("xmake.lua") then
                table.insert(latest, path.filename(path.directory(line)))
            end
        end
    end
    return table.slice(latest, 1, 3)
end

-- build packages
function build_packages()
    -- clone xmake-repo
    local url = "https://github.com/xmake-io/xmake-repo"
    local repodir = path.join(os.tmpdir(), "xrepo-docs", "xmake-repo")
    print("clone %s => %s", url, repodir)
    os.tryrm(repodir)
    git.clone(url, {outputdir = repodir})

    -- load packages
    os.cd(repodir)
    local packages = import("scripts.packages", {rootdir = repodir, anonymous = true})()
    local latest = latest_packages()
    os.cd("-")

    -- get total packages
    local total_packages = {}
    for _, pkgs in pairs(packages) do
        for _, pkg in ipairs(pkgs) do
            table.insert(total_packages, pkg.name)
        end
    end
    total_packages = table.unique(total_packages)

    -- generate _sidebar.md
    print("generate _sidebar.md")
    local sidebar = io.open("_sidebar.md", "w")
    sidebar:print("- Getting Started")
    sidebar:print("  - [Sponsor](https://xmake.io/#/about/sponsor)")
    sidebar:print("  - [Quick Start](getting_started.md)")
    sidebar:print("- Packages (%s)", #total_packages)
    local plats = table.keys(packages)
    table.sort(plats)
    for _, plat in ipairs(plats) do
        sidebar:print("  - [%s](packages/%s.md)", plat, plat)
    end
    sidebar:close()

    -- generate zh-cn/_sidebar.md
    print("generate zh-cn/_sidebar.md")
    local sidebar = io.open("zh-cn/_sidebar.md", "w")
    sidebar:print("- 快速入门")
    sidebar:print("  - [赞助](https://xmake.io/#/zh-cn/about/sponsor)")
    sidebar:print("  - [快速上手](zh-cn/getting_started.md)")
    sidebar:print("- 包列表 (%s)", #total_packages)
    for _, plat in ipairs(plats) do
        sidebar:print("  - [%s](packages/%s.md)", plat, plat)
    end
    sidebar:close()

    -- generate packages/*.md
    print("generate packages/*.md")
    for _, plat in ipairs(plats) do
        local pkgs = packages[plat]
        local list = {}
        for _, pkg in ipairs(pkgs) do
            local key = pkg.name:sub(1, 1)
            list[key] = list[key] or {}
            table.insert(list[key], pkg)
        end
        local keys = table.keys(list)
        table.sort(keys)
        local file = io.open(path.join("packages", plat .. ".md"), "w")
        for _, key in ipairs(keys) do
            file:print("## %s", key)
            for _, pkg in ipairs(list[key]) do
                write_package(file, pkg.instance, plat, pkg.archs)
            end
            file:print("")
        end
        file:close()
    end

    -- generate latest added packages
    print(os.files("*"))
    io.gsub("_coverpage.md", "%*%*Recently added:.*%*%*", "**Recently added: " .. table.concat(latest, ", ") .. "**")
    io.gsub("zh-cn/_coverpage.md", "%*%*Recently added:.*%*%*", "**Recently added: " .. table.concat(latest, ", ") .. "**")
end

-- main entry
function main()
    print(os.scriptdir())
    os.cd(path.directory(os.scriptdir()))
    print(os.files("*"))
    build_packages()
    build_mirror_files()
end

