-- Developer Product IDs live here. Fill `id` after publishing the place
-- and creating the products in the Creator Dashboard (Monetization > Developer Products).
-- While `id` is 0 the shop row stays disabled and no purchase is attempted.
local Config = {}

Config.Products = {
	{ id = 0, name = "CHIP PACK", cash = 5000, price = "99 R$" },
	{ id = 0, name = "HIGH ROLLER PACK", cash = 25000, price = "499 R$" },
	{ id = 0, name = "WHALE VAULT", cash = 100000, price = "1,999 R$" },
}

-- Game pass that grants +50% passive income. Set `vip` to the pass id after publishing.
Config.GamePasses = {
	vip = 0,
}

Config.VipIncomeMultiplier = 1.5

return Config
