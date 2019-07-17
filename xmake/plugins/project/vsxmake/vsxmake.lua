--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015 - 2019, TBOOX Open Source Group.
--
-- @author      OpportunityLiu
-- @file        vsxmake.lua
--

-- imports
import("core.base.hashset")
import("vstudio.impl.vsinfo", { rootdir = path.directory(os.scriptdir()) })
import("render")
import("getinfo")

local template_root = path.join(os.scriptdir(), "vsproj", "templates")
local template_sln = path.join(template_root, "sln", "vsxmake.sln")
local template_vcx = path.join(template_root, "vcxproj", "#target#.vcxproj")

local template_fil = path.join(template_root, "vcxproj.filters", "#target#.vcxproj.filters")
local template_usr = path.join(template_root, "#target#.vcxproj.user")
local template_props = path.join(template_root, "Xmake.Custom.props")
local template_targets = path.join(template_root, "Xmake.Custom.targets")

function _filter_files(files, exts)
    local extset = hashset.from(exts)
    local f = {}
    for _, file in ipairs(files) do
        local ext = path.extension(file)
        if extset:has(ext) then
            table.insert(f, file)
        end
    end
    return f
end

-- escape special chars in msbuild file
function _escape(str)
    if not str then
        return nil
    end

    local map =
    {    ["%"] = "%25" -- Referencing metadata
        ,["$"] = "%24" -- Referencing properties
        ,["@"] = "%40" -- Referencing item lists
        ,["'"] = "%27" -- Conditions and other expressions
        ,[";"] = "%3B" -- List separator
        ,["?"] = "%3F" -- Wildcard character for file names in Include and Exclude attributes
        ,["*"] = "%2A" -- Wildcard character for use in file names in Include and Exclude attributes
    }

    local has_prefix = false
    if str:startswith("$(XmakeProjectDir)") then
        has_prefix = true
        str = str:sub(#("$(XmakeProjectDir)") + 1)
    end

    str = (string.gsub(str, "[%%%$@';%?%*]", function (c) return assert(map[c]) end))
    if has_prefix then
        str = "$(XmakeProjectDir)" .. str
    end
    return str
end

function _buildparams(info, target, default)

    local function getprop(match, opt)
        local i = info
        local r = info[match]
        if target then
            opt = table.join(target, opt)
        end
        for _,k in ipairs(opt) do
            local v = (i._sub or {})[k] or (i._sub2 or {})[k] or (i._sub3 or {})[k] or (i._sub4 or {})[k]or i[k]
            if v == nil then
                raise("key '" .. k .. "' not found")
            end
            i = v
            r = i[match] or r
        end

        return _escape(r) or default
    end

    local function listconfig(args)
        for _, k in ipairs(args) do
            args[k] = true
        end
        local r = {}
        if args.target then
            table.insert(r, info.targets)
        end
        if args.mode then
            table.insert(r, info.modes)
        end
        if args.arch then
            table.insert(r, info.archs)
        end
        if args.dir then
            table.insert(r, info._sub[target].dirs)
        end
        if args.dep then
            table.insert(r, info._sub[target].deps)
        end
        if args.filec then
            local files = info._sub[target].sourcefiles
            table.insert(r, _filter_files(files, {".c"}))
        elseif args.filecxx then
            local files = info._sub[target].sourcefiles
            table.insert(r, _filter_files(files, {".cpp", ".cc", ".cxx"}))
        elseif args.filecu then
            local files = info._sub[target].sourcefiles
            table.insert(r, _filter_files(files, {".cu"}))
        elseif args.fileobj then
            local files = info._sub[target].sourcefiles
            table.insert(r, _filter_files(files, {".obj", ".o"}))
        elseif args.filerc then
            local files = info._sub[target].sourcefiles
            table.insert(r, _filter_files(files, {".rc"}))
        elseif args.inc then
            table.insert(r, info._sub[target].headerfiles)
        end
        return r
    end

    return function(match, opt)
        if type(match) == "table" then
            return listconfig(match)
        end
        return getprop(match, opt)
    end
end

function _trycp(file, target, targetname)
    targetname = targetname or path.filename(file)
    local targetfile = path.join(target, targetname)
    if os.isfile(targetfile) then
        dprint("skipped file %s", path.relative(targetfile))
        return
    end
    os.cp(file,targetfile)
end

-- make
function make(version)

    return function(outputdir)
        local info = getinfo(outputdir, vsinfo(version))
        local paramsprovidersln = _buildparams(info)

        -- write solution file
        local sln = path.join(info.solution_dir, info.slnfile .. "_vsxmake" .. info.vstudio_version .. ".sln")
        io.writefile(sln, render(template_sln, "#([A-Za-z0-9_,%.%*%(%)]+)#", paramsprovidersln))

        -- add solution custom file
        _trycp(template_props, info.solution_dir)
        _trycp(template_targets, info.solution_dir)

        for _, target in ipairs(info.targets) do
            local paramsprovidertarget = _buildparams(info, target, "<!-- nil -->")
            local proj_dir = info._sub[target].vcxprojdir

            -- write project file
            local proj = path.join(proj_dir, target .. ".vcxproj")
            io.writefile(proj, render(template_vcx, "#([A-Za-z0-9_,%.%*%(%)]+)#", paramsprovidertarget))

            local projfil = path.join(proj_dir, target .. ".vcxproj.filters")
            io.writefile(projfil, render(template_fil, "#([A-Za-z0-9_,%.%*%(%)]+)#", paramsprovidertarget))

            -- add project custom file
            _trycp(template_props, proj_dir)
            _trycp(template_targets, proj_dir)
            -- add project user file
            _trycp(template_usr, proj_dir, target .. ".vcxproj.user")
        end
    end
end
