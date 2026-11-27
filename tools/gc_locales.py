"""Game Center texts per App Store locale (en-US and ru; Game Center falls back to the primary language)."""
_EN = {
    "first_tree": ("First Harvest", "Chop your first tree"), "lumberjack": ("Lumberjack", "Chop 500 trees"),
    "miner": ("Miner", "Break 500 rocks"), "berry": ("Berry Picker", "Pick 300 bushes"),
    "fisher": ("Angler", "Fish in ponds 100 times"), "furnace": ("Fire in the Furnace", "Build a furnace"),
    "builder": ("Builder", "Build every building"), "islands3": ("Traveler", "Own three islands"),
    "islands6": ("Seafarer", "Own six islands"), "islands12": ("The Whole Archipelago", "Unlock every island"),
    "level10": ("Sprout", "Reach level 10"), "level25": ("Flower", "Reach level 25"), "level50": ("Great Tree", "Reach level 50"),
    "helpers3": ("Happy Family", "Grow three Bloomlings"), "gold_pick": ("Golden Pickaxe", "Forge the golden pickaxe"),
    "obsidian_pick": ("Harder Than Stone", "Forge the obsidian pickaxe"), "chests": ("Treasure Hunter", "Open 50 chests"),
    "album": ("Collector", "Complete every album page"), "spring": ("New Spring", "Welcome a new spring"),
    "spring5": ("Eternal Garden", "Welcome five new springs"), "week": ("A Week in the Garden", "Claim all seven login gifts"),
    "event": ("Life of the Party", "Finish a weekly event"), "lantern": ("Stargazer", "Make a star lantern"),
}
_RU = {
    "first_tree": ("Первый урожай", "Сруби первое дерево"), "lumberjack": ("Лесоруб", "Сруби 500 деревьев"),
    "miner": ("Горняк", "Разбей 500 камней"), "berry": ("Ягодник", "Обери 300 кустов"),
    "fisher": ("Рыбак", "Порыбачь в прудах 100 раз"), "furnace": ("Огонь в печи", "Построй печь"),
    "builder": ("Строитель", "Построй все постройки"), "islands3": ("Путешественник", "Владей тремя островами"),
    "islands6": ("Мореход", "Владей шестью островами"), "islands12": ("Весь архипелаг", "Открой все острова"),
    "level10": ("Росток", "Достигни 10 уровня"), "level25": ("Цветок", "Достигни 25 уровня"), "level50": ("Древо", "Достигни 50 уровня"),
    "helpers3": ("Дружная семья", "Вырасти трёх блумлингов"), "gold_pick": ("Золотая кирка", "Выкуй золотую кирку"),
    "obsidian_pick": ("Сильнее камня", "Выкуй обсидиановую кирку"), "chests": ("Кладоискатель", "Открой 50 сундуков"),
    "album": ("Коллекционер", "Собери все страницы альбома"), "spring": ("Новая весна", "Встреть новую весну"),
    "spring5": ("Вечный сад", "Встреть пять новых вёсен"), "week": ("Неделя в саду", "Забери все семь подарков за вход"),
    "event": ("Душа праздника", "Пройди событие до конца"), "lantern": ("Звездочёт", "Собери звёздный фонарь"),
}
ACH = {k: [("en-US", _EN[k][0], _EN[k][1], _EN[k][1] + ". Done!"),
           ("ru", _RU[k][0], _RU[k][1], _RU[k][1] + ". Готово!")] for k in _EN}
LB = {
    "bloom.lb.level": [("en-US", "Highest Level"), ("ru", "Высший уровень")],
    "bloom.lb.gathered": [("en-US", "Gathered in Total"), ("ru", "Всего добыто")],
    "bloom.lb.springs": [("en-US", "New Springs"), ("ru", "Новые вёсны")],
}
