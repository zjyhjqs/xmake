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
-- Copyright (C) 2015-present, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        dlist.lua
--

-- load modules
local object = require("base/object")

-- define module
local dlist = dlist or object { _init = {"_length"} } {0}

-- clear list
function dlist:clear()
    self._length = 0
    self._first  = nil
    self._last   = nil
end

-- insert item after the given item
function dlist:insert(t, after)
    if not after then
        return self:insert_tail(t)
    end
    assert(t ~= after)
    if after._next then
        after._next._prev = t
        t._next = after._next
    else
        self._last = t
    end
    t._prev = after
    after._next = t
    self._length = self._length + 1
end

-- insert item in head
function dlist:insert_head(t)
    if self._first then
        self._first._prev = t
        t._next = self._first
        self._first = t
    else
        self._first = t
        self._last = t
    end
    self._length = self._length + 1
end

-- insert item in tail
function dlist:insert_tail(t)
    if self._last then
        self._last._next = t
        t._prev = self._last
        self._last = t
    else
        self._first = t
        self._last = t
    end
    self._length = self._length + 1
end

-- remove item
function dlist:remove(t)
    if t._next then
        if t._prev then
            t._next._prev = t._prev
            t._prev._next = t._next
        else
            assert(t == self._first)
            t._next._prev = nil
            self._first = t._next
        end
    elseif t._prev then
        assert(t == self._last)
        t._prev._next = nil
        self._last = t._prev
    else
        assert(t == self._first and t == self._last)
        self._first = nil
        self._last = nil
    end
    t._next = nil
    t._prev = nil
    self._length = self._length - 1
    return t
end

-- remove the first item
function dlist:remove_first()
    if not self._first then
        return
    end
    local t = self._first
    if t._next then
        t._next._prev = nil
        self._first = t._next
        t._next = nil
    else
        self._first = nil
        self._last = nil
    end
    self._length = self._length - 1
    return t
end

-- remove last item
function dlist:remove_last()
    if not self._last then
        return
    end
    local t = self._last
    if t._prev then
        t._prev._next = nil
        self._last = t._prev
        t._prev = nil
    else
        self._first = nil
        self._last = nil
    end
    self._length = self._length - 1
    return t
end

-- push item to tail
function dlist:push(t)
    self:insert_tail(t)
end

-- pop item from tail
function dlist:pop()
    self:remove_last()
end

-- shift item: 1 2 3 <- 2 3
function dlist:shift()
    self:remove_first()
end

-- unshift item: 1 2 -> t 1 2
function dlist:unshift(t)
    self:insert_head(t)
end

-- get first item
function dlist:first()
    return self._first
end

-- get last item
function dlist:last()
    return self._last
end

-- get next item
function dlist:next(last)
    if last then
        return last._next
    else
        return self._first
    end
end

-- get the previous item
function dlist:prev(last)
    if last then
        return last._prev
    else
        return self._last
    end
end

-- get list size
function dlist:size()
    return self._length
end

-- is empty?
function dlist:empty()
    return self:size() == 0
end

-- get items
--
-- e.g.
--
-- for item in dlist:items() do
--     print(item)
-- end
--
function dlist:items()
    local iter = function (list, item)
        return list:next(item)
    end
    return iter, self, nil
end

-- get reverse items
function dlist:ritems()
    local iter = function (list, item)
        return list:prev(item)
    end
    return iter, self, nil
end

-- new dlist
function dlist.new()
    return dlist()
end

-- return module: dlist
return dlist
