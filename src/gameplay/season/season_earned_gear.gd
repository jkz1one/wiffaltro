class_name SeasonEarnedGear
extends RefCounted
## Equipment/Sponsors v18 numeric candidates remain Working. Alley tiers remain gated.

const ITEMS: Dictionary = {
	"BAT-CON-02":
	{
		"name": "Jumbo Barrel Bat",
		"slot": "bat",
		"price": 15,
		"radius": 1.1,
		"exit": 0.93,
		"effect": "Both contact radii +10%; fair exit speed −7%."
	},
	"BAT-CON-03":
	{
		"name": "Paddle Bat",
		"slot": "bat",
		"price": 20,
		"radius": 1.15,
		"exit": 0.9,
		"effect": "Both contact radii +15%; fair exit speed −10%."
	},
	"BAT-POW-02":
	{
		"name": "Loaded Bat",
		"slot": "bat",
		"price": 15,
		"radius": 0.9,
		"exit": 1.08,
		"effect": "Fair exit speed +8%; both contact radii −10%."
	},
	"BAT-POW-03":
	{
		"name": "Moonshot Bat",
		"slot": "bat",
		"price": 20,
		"radius": 0.85,
		"exit": 1.12,
		"effect": "Fair exit speed +12%; both contact radii −15%."
	},
	"BALL-MOV-02":
	{
		"name": "Cut Ball",
		"slot": "ball",
		"price": 14,
		"velocity": 0.94,
		"movement": 1.15,
		"effect": "Pitch velocity −6%; authored movement +15%."
	},
	"BALL-MOV-03":
	{
		"name": "Razor Ball",
		"slot": "ball",
		"price": 18,
		"velocity": 0.9,
		"movement": 1.24,
		"effect": "Pitch velocity −10%; authored movement +24%."
	},
	"BALL-VEL-02":
	{
		"name": "Speed Ball",
		"slot": "ball",
		"price": 14,
		"velocity": 1.06,
		"movement": 0.85,
		"effect": "Pitch velocity +6%; authored movement −15%."
	},
	"BALL-VEL-03":
	{
		"name": "Rocket Ball",
		"slot": "ball",
		"price": 18,
		"velocity": 1.1,
		"movement": 0.76,
		"effect": "Pitch velocity +10%; authored movement −24%."
	},
	"BALL-HYB-02":
	{
		"name": "Livewire Ball",
		"slot": "ball",
		"price": 16,
		"velocity": 1.04,
		"movement": 1.09,
		"command": 1.2,
		"effect": "Pitch velocity +4%; authored movement +9%; command dispersion +20%."
	},
	"BALL-HYB-03":
	{
		"name": "Overcharged Ball",
		"slot": "ball",
		"price": 20,
		"velocity": 1.06,
		"movement": 1.14,
		"command": 1.35,
		"effect": "Pitch velocity +6%; authored movement +14%; command dispersion +35%."
	}
}
