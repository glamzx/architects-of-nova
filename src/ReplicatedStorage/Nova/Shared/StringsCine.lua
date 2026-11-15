-- StringsCine: strings owned by the cinematics/audio workstream. Entries:  key = { "русский", "English" }.
local P = {
	-- cold open: what happened to Earth (short, one idea per caption)
	cine_1 = { "2089 год. Наше Солнце.", "2089. Our Sun." },
	cine_2 = { "Однажды ночью оно вспыхнуло — сильнее, чем за последние 500 лет.", "One night it flared up, stronger than any storm in 500 years." },
	cine_3 = { "Огромная волна солнечной плазмы помчалась к Земле.", "A giant wave of solar plasma raced toward Earth." },
	cine_4 = { "Небо запылало огненным сиянием. Все спутники сгорели.", "The sky blazed with fiery auroras. Every satellite burned out." },
	cine_5 = { "Города погасли. Колонии на Луне и Марсе замолчали.", "Cities went dark. The colonies on the Moon and Mars fell silent." },
	cine_6 = { "Вторая волна придёт через 72 часа.", "The second wave arrives in 72 hours." },
	cine_7 = { "Но в Цитадели свет ещё горит. Мастер Кейд собирает кадетов.", "But the Citadel still has power. Master Kade is calling the cadets." },
	cine_label = { "Солнечная буря · 2089", "Solar storm · 2089" },
	-- subtitle box tags
	cine_tag_holo = { "Голосвязь", "Holo link" },
	cine_tag_radio = { "Радио", "Radio" },
	cine_tag_comms = { "Связь", "Comms" },
	-- vote panel
	cine_vote_hint = { "Нажми на карточку или клавишу 1 / 2", "Click a card or press 1 / 2" },
	cine_skip = { "Пропустить", "Skip" },
}
local out = { ru = {}, en = {} }
for k, v in P do out.ru[k] = v[1] out.en[k] = v[2] end
return out
