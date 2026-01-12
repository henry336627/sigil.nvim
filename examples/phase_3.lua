-- ============================================
-- Phase 3 Test: Context-Aware Prettification
-- ============================================
--
-- Инструкция:
-- 1. :lua require("sigil").setup()
-- 2. :set conceallevel=2
--
-- Ожидаемый результат:
-- - Символы В КОДЕ prettify (lambda -> λ, -> -> →)
-- - Символы В КОММЕНТАРИЯХ остаются как есть
-- - Символы В СТРОКАХ остаются как есть
-- ============================================

-- КОММЕНТАРИИ: lambda, ->, ~= должны ОСТАТЬСЯ как есть
-- Вот ещё lambda в комментарии
-- И стрелка -> тоже не должна меняться

-- СТРОКИ: символы внутри НЕ должны prettify
local str1 = "lambda в строке остаётся lambda"
local str2 = "стрелка -> тоже остаётся ->"
local str3 = 'и в одинарных кавычках lambda тоже'

-- КОД: здесь символы ДОЛЖНЫ prettify
local lambda = "это переменная, lambda слева должна стать λ"
local f = function(x)
    return x
end

-- Операторы в коде ДОЛЖНЫ prettify:
local a = 1
local b = 2
if a ~= b then  -- ~= -> ≠ (Lua style not-equal)
    print("not equal")
end

if a <= b then  -- <= -> ≤
    print("less or equal")
end

if a >= b then  -- >= -> ≥
    print("greater or equal")
end

-- Стрелки в коде (не в строках):
-- Примечание: в Lua нет ->, но для демонстрации:
local arrow_demo = "смотри на эту строку, внутри -> не меняется"
-- А вот если бы -> был в коде, он бы стал →

-- nil должен стать ∅
local nothing = nil

-- ============================================
-- Дополнительные тесты:
-- ============================================

-- Тест skip_strings = false:
-- :lua require("sigil").setup({ skip_strings = false })
-- :lua require("sigil").refresh()
-- Теперь lambda в строках тоже должна стать λ

-- Тест skip_comments = false:
-- :lua require("sigil").setup({ skip_comments = false })
-- :lua require("sigil").refresh()
-- Теперь lambda в комментариях тоже должна стать λ

-- Тест custom predicate (только стрелки):
-- :lua require("sigil").setup({
--   predicate = function(ctx) return ctx.pattern == "->" end
-- })
-- :lua require("sigil").refresh()
