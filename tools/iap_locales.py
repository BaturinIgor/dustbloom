"""Store names/descriptions of the Bloom shop products per App Store locale.
Order of each list: founder, pass28, jar, gems.80, gems.450, gems.1000, gems.2200.
Name <= 30 chars, description <= 45 chars (App Store Connect limits)."""

IDS = ["bloom.founder", "bloom.pass28", "bloom.jar", "bloom.gems.80", "bloom.gems.450", "bloom.gems.1000", "bloom.gems.2200"]

L = {
 "en-US": [("Founder Pack", "Golden Bloomling, +30% regrowth, 300 dew"), ("Bloom Pass", "+25% loot and XP for 28 days"),
           ("Dew Jar", "All the dew saved up in the jar"), ("80 Dew", "A handful of dew for the shop"),
           ("450 Dew", "A pouch of dew for the shop"), ("1000 Dew", "A jug of dew for the shop"), ("2200 Dew", "A whole lake of dew, best value")],
 "ru": [("Набор основателя", "Золотой блумлинг, рост +30% и 300 росинок"), ("Пропуск цветения", "+25% добычи и опыта на 28 дней"),
        ("Банка росы", "Все росинки, накопленные в банке"), ("80 росинок", "Горсть росинок для лавки"),
        ("450 росинок", "Мешочек росинок для лавки"), ("1000 росинок", "Кувшин росинок для лавки"), ("2200 росинок", "Целое озеро росинок, лучшая цена")],
 "uk": [("Набір засновника", "Золотий блумлінг, ріст +30% і 300 росинок"), ("Перепустка цвітіння", "+25% здобичі й досвіду на 28 днів"),
        ("Банка роси", "Усі росинки, зібрані в банці"), ("80 росинок", "Жменька росинок для крамниці"),
        ("450 росинок", "Мішечок росинок для крамниці"), ("1000 росинок", "Глечик росинок для крамниці"), ("2200 росинок", "Ціле озеро росинок, найкраща ціна")],
 "de-DE": [("Gründerpaket", "Goldener Bloomling, +30% Nachwuchs, 300 Tau"), ("Blütenpass", "+25% Beute und EP für 28 Tage"),
           ("Tauglas", "Der ganze gesammelte Tau im Glas"), ("80 Tau", "Eine Handvoll Tau für den Laden"),
           ("450 Tau", "Ein Beutel Tau für den Laden"), ("1000 Tau", "Ein Krug Tau für den Laden"), ("2200 Tau", "Ein ganzer See Tau, bester Preis")],
 "fr-FR": [("Pack Fondateur", "Bloomling doré, +30% repousse, 300 rosée"), ("Pass Floraison", "+25% butin et XP pendant 28 jours"),
           ("Bocal de rosée", "Toute la rosée gardée dans le bocal"), ("80 rosée", "Une poignée de rosée pour la boutique"),
           ("450 rosée", "Une bourse de rosée pour la boutique"), ("1000 rosée", "Une cruche de rosée pour la boutique"), ("2200 rosée", "Un lac de rosée, meilleur prix")],
 "es-ES": [("Pack Fundador", "Bloomling dorado, +30% rebrote, 300 rocío"), ("Pase Floración", "+25% botín y XP durante 28 días"),
           ("Tarro de rocío", "Todo el rocío guardado en el tarro"), ("80 rocío", "Un puñado de rocío para la tienda"),
           ("450 rocío", "Una bolsa de rocío para la tienda"), ("1000 rocío", "Una jarra de rocío para la tienda"), ("2200 rocío", "Un lago de rocío, mejor precio")],
 "es-MX": [("Paquete Fundador", "Bloomling dorado, +30% rebrote, 300 rocío"), ("Pase Floración", "+25% botín y XP por 28 días"),
           ("Frasco de rocío", "Todo el rocío guardado en el frasco"), ("80 rocío", "Un puñado de rocío para la tienda"),
           ("450 rocío", "Una bolsa de rocío para la tienda"), ("1000 rocío", "Una jarra de rocío para la tienda"), ("2200 rocío", "Un lago de rocío, mejor precio")],
 "it": [("Pacchetto Fondatore", "Bloomling d’oro, +30% ricrescita, 300 rugiada"), ("Pass Fioritura", "+25% bottino e XP per 28 giorni"),
        ("Barattolo di rugiada", "Tutta la rugiada messa da parte"), ("80 rugiada", "Una manciata di rugiada per il negozio"),
        ("450 rugiada", "Un sacchetto di rugiada per il negozio"), ("1000 rugiada", "Una brocca di rugiada per il negozio"), ("2200 rugiada", "Un lago di rugiada, miglior prezzo")],
 "pt-BR": [("Pacote Fundador", "Bloomling dourado, +30% rebrota, 300 orvalho"), ("Passe Florescer", "+25% de saque e XP por 28 dias"),
           ("Pote de orvalho", "Todo o orvalho guardado no pote"), ("80 orvalho", "Um punhado de orvalho para a loja"),
           ("450 orvalho", "Uma bolsa de orvalho para a loja"), ("1000 orvalho", "Uma jarra de orvalho para a loja"), ("2200 orvalho", "Um lago de orvalho, melhor preço")],
 "pt-PT": [("Pacote Fundador", "Bloomling dourado, +30% rebento, 300 orvalho"), ("Passe Florescer", "+25% de saque e XP durante 28 dias"),
           ("Frasco de orvalho", "Todo o orvalho guardado no frasco"), ("80 orvalho", "Um punhado de orvalho para a loja"),
           ("450 orvalho", "Uma bolsa de orvalho para a loja"), ("1000 orvalho", "Um jarro de orvalho para a loja"), ("2200 orvalho", "Um lago de orvalho, melhor preço")],
 "nl-NL": [("Oprichterspakket", "Gouden Bloomling, +30% aangroei, 300 dauw"), ("Bloeipas", "+25% buit en XP voor 28 dagen"),
           ("Dauwpot", "Alle dauw die in de pot is gespaard"), ("80 dauw", "Een handvol dauw voor de winkel"),
           ("450 dauw", "Een buidel dauw voor de winkel"), ("1000 dauw", "Een kan dauw voor de winkel"), ("2200 dauw", "Een heel meer dauw, beste prijs")],
 "pl": [("Pakiet Założyciela", "Złoty Bloomling, +30% odrostu, 300 rosy"), ("Przepustka Rozkwitu", "+25% łupów i PD przez 28 dni"),
        ("Słoik rosy", "Cała rosa zebrana w słoiku"), ("80 rosy", "Garść rosy do sklepu"),
        ("450 rosy", "Sakiewka rosy do sklepu"), ("1000 rosy", "Dzban rosy do sklepu"), ("2200 rosy", "Całe jezioro rosy, najlepsza cena")],
 "tr": [("Kurucu Paketi", "Altın Bloomling, +%30 yeniden büyüme, 300 çiy"), ("Çiçek Kartı", "28 gün boyunca +%25 ganimet ve XP"),
        ("Çiy Kavanozu", "Kavanozda biriken tüm çiy"), ("80 Çiy", "Dükkan için bir avuç çiy"),
        ("450 Çiy", "Dükkan için bir kese çiy"), ("1000 Çiy", "Dükkan için bir testi çiy"), ("2200 Çiy", "Koca bir göl çiy, en iyi fiyat")],
 "ja": [("創設者パック", "金のブルームリング、再生+30%、しずく300"), ("ブルームパス", "28日間 戦利品と経験値+25%"),
        ("しずくの瓶", "瓶に貯まったしずくをすべて"), ("しずく80", "ショップ用のしずくひとつかみ"),
        ("しずく450", "ショップ用のしずく小袋"), ("しずく1000", "ショップ用のしずく水差し"), ("しずく2200", "しずくの湖、いちばんお得")],
 "ko": [("창립자 팩", "황금 블룸링, 재생 +30%, 이슬 300"), ("블룸 패스", "28일간 전리품과 경험치 +25%"),
        ("이슬 병", "병에 모아 둔 이슬 전부"), ("이슬 80", "상점용 이슬 한 줌"),
        ("이슬 450", "상점용 이슬 주머니"), ("이슬 1000", "상점용 이슬 한 주전자"), ("이슬 2200", "이슬 호수, 최고의 가성비")],
 "zh-Hans": [("创始者礼包", "金色花灵、再生+30%、300露珠"), ("花开通行证", "28天内战利品和经验+25%"),
             ("露珠罐", "罐中攒下的全部露珠"), ("80露珠", "一把露珠，商店使用"),
             ("450露珠", "一袋露珠，商店使用"), ("1000露珠", "一壶露珠，商店使用"), ("2200露珠", "一整湖露珠，最超值")],
 "zh-Hant": [("創始者禮包", "金色花靈、再生+30%、300露珠"), ("花開通行證", "28天內戰利品和經驗+25%"),
             ("露珠罐", "罐中攢下的全部露珠"), ("80露珠", "一把露珠，商店使用"),
             ("450露珠", "一袋露珠，商店使用"), ("1000露珠", "一壺露珠，商店使用"), ("2200露珠", "一整湖露珠，最超值")],
 "ar-SA": [("حزمة المؤسس", "بلوملينغ ذهبي، نمو +30%، 300 ندى"), ("تذكرة التفتح", "+25% غنائم وخبرة لمدة 28 يومًا"),
           ("جرة الندى", "كل الندى المدخر في الجرة"), ("80 ندى", "حفنة ندى للمتجر"),
           ("450 ندى", "كيس ندى للمتجر"), ("1000 ندى", "إبريق ندى للمتجر"), ("2200 ندى", "بحيرة كاملة من الندى، أفضل قيمة")],
 "th": [("แพ็กผู้ก่อตั้ง", "บลูมลิงทองคำ งอกใหม่ +30% น้ำค้าง 300"), ("บลูมพาส", "ของรางวัลและ XP +25% นาน 28 วัน"),
        ("โหลน้ำค้าง", "น้ำค้างทั้งหมดที่สะสมในโหล"), ("น้ำค้าง 80", "น้ำค้างหนึ่งกำมือสำหรับร้านค้า"),
        ("น้ำค้าง 450", "น้ำค้างหนึ่งถุงสำหรับร้านค้า"), ("น้ำค้าง 1000", "น้ำค้างหนึ่งเหยือกสำหรับร้านค้า"), ("น้ำค้าง 2200", "ทะเลสาบน้ำค้าง คุ้มที่สุด")],
 "vi": [("Gói Sáng Lập", "Bloomling vàng, mọc lại +30%, 300 sương"), ("Vé Nở Hoa", "+25% chiến lợi phẩm và XP trong 28 ngày"),
        ("Hũ sương", "Toàn bộ sương tích trong hũ"), ("80 sương", "Một nắm sương cho cửa hàng"),
        ("450 sương", "Một túi sương cho cửa hàng"), ("1000 sương", "Một bình sương cho cửa hàng"), ("2200 sương", "Cả hồ sương, giá tốt nhất")],
 "id": [("Paket Pendiri", "Bloomling emas, tumbuh +30%, 300 embun"), ("Bloom Pass", "+25% jarahan dan XP selama 28 hari"),
        ("Toples Embun", "Semua embun yang tersimpan di toples"), ("80 Embun", "Segenggam embun untuk toko"),
        ("450 Embun", "Sekantong embun untuk toko"), ("1000 Embun", "Sekendi embun untuk toko"), ("2200 Embun", "Sedanau embun, harga terbaik")],
 "sv": [("Grundarpaket", "Gyllene Bloomling, +30% återväxt, 300 dagg"), ("Blomningspass", "+25% byte och XP i 28 dagar"),
        ("Daggburk", "All dagg som sparats i burken"), ("80 dagg", "En handfull dagg till butiken"),
        ("450 dagg", "En pung dagg till butiken"), ("1000 dagg", "En kanna dagg till butiken"), ("2200 dagg", "En hel sjö av dagg, bästa pris")],
}

def table():
    """{productId: [(locale, name, description), ...]}"""
    out = {pid: [] for pid in IDS}
    for loc, rows in L.items():
        assert len(rows) == len(IDS), loc
        for pid, (n, d) in zip(IDS, rows):
            out[pid].append((loc, n, d))
    return out


# Added for 1.0: starter pack, nursery slot, event pass (same order as IDS2).
IDS2 = ["bloom.starter", "bloom.slot", "bloom.eventpass"]
L2 = {
 "en-US": [("Starter Pack", "150 dew, coins, wood, stone and the Mint look"), ("Nursery Slot", "One more Bloomling helper, forever"), ("Event Pass", "All rewards of this week's event")],
 "ru": [("Стартовый набор", "150 росинок, монеты, дерево, камень и облик"), ("Место в питомнике", "Ещё один блумлинг-помощник навсегда"), ("Пропуск события", "Все награды события этой недели")],
 "uk": [("Стартовий набір", "150 росинок, монети, дерево, камінь і образ"), ("Місце в розсаднику", "Ще один блумлінг-помічник назавжди"), ("Перепустка події", "Усі нагороди події цього тижня")],
 "de-DE": [("Starterpaket", "150 Tau, Münzen, Holz, Stein und Minz-Look"), ("Gärtnerei-Platz", "Ein weiterer Bloomling-Helfer, für immer"), ("Eventpass", "Alle Belohnungen des Wochenevents")],
 "fr-FR": [("Pack de départ", "150 rosée, pièces, bois, pierre, look menthe"), ("Place à la pépinière", "Un Bloomling de plus, pour toujours"), ("Pass d'événement", "Toutes les récompenses de la semaine")],
 "es-ES": [("Pack de inicio", "150 rocío, monedas, madera, piedra y menta"), ("Hueco en el vivero", "Un Bloomling ayudante más, para siempre"), ("Pase del evento", "Todas las recompensas del evento semanal")],
 "es-MX": [("Paquete inicial", "150 rocío, monedas, madera, piedra y menta"), ("Lugar en el vivero", "Un Bloomling ayudante más, para siempre"), ("Pase del evento", "Todas las recompensas del evento semanal")],
 "it": [("Pacchetto iniziale", "150 rugiada, monete, legno, pietra e look"), ("Posto nel vivaio", "Un Bloomling aiutante in più, per sempre"), ("Pass evento", "Tutte le ricompense dell'evento")],
 "pt-BR": [("Pacote inicial", "150 orvalho, moedas, madeira, pedra e menta"), ("Vaga no viveiro", "Mais um Bloomling ajudante, para sempre"), ("Passe do evento", "Todas as recompensas do evento da semana")],
 "pt-PT": [("Pacote inicial", "150 orvalho, moedas, madeira, pedra e menta"), ("Lugar no viveiro", "Mais um Bloomling ajudante, para sempre"), ("Passe do evento", "Todas as recompensas do evento da semana")],
 "nl-NL": [("Starterspakket", "150 dauw, munten, hout, steen en munt-look"), ("Kwekerijplek", "Nog een Bloomling-helper, voor altijd"), ("Eventpas", "Alle beloningen van het weekevent")],
 "pl": [("Zestaw startowy", "150 rosy, monety, drewno, kamień i mięta"), ("Miejsce w szkółce", "Jeszcze jeden Bloomling na zawsze"), ("Karnet wydarzenia", "Wszystkie nagrody wydarzenia tygodnia")],
 "tr": [("Başlangıç paketi", "150 çiy, altın, odun, taş ve nane görünümü"), ("Fidanlık yeri", "Bir Bloomling yardımcı daha, sonsuza dek"), ("Etkinlik bileti", "Bu haftaki etkinliğin tüm ödülleri")],
 "ja": [("スターターパック", "しずく150、コイン、木材、石、ミントの見た目"), ("苗床の追加枠", "ブルームリングの仲間がずっと1匹増える"), ("イベントパス", "今週のイベントの報酬すべて")],
 "ko": [("스타터 팩", "이슬 150, 코인, 목재, 돌, 민트 외형"), ("묘목장 자리", "블룸링 도우미 한 마리 영구 추가"), ("이벤트 패스", "이번 주 이벤트의 모든 보상")],
 "zh-Hans": [("新手礼包", "150露珠、金币、木材、石头和薄荷外观"), ("苗圃位置", "永久多一只花灵助手"), ("活动通行证", "本周活动的全部奖励")],
 "zh-Hant": [("新手禮包", "150露珠、金幣、木材、石頭和薄荷外觀"), ("苗圃位置", "永久多一隻花靈助手"), ("活動通行證", "本週活動的全部獎勵")],
 "ar-SA": [("حزمة البداية", "150 ندى وعملات وخشب وحجر ومظهر نعناعي"), ("مكان في المشتل", "مساعد بلوملينغ إضافي إلى الأبد"), ("تذكرة الحدث", "كل مكافآت حدث هذا الأسبوع")],
 "th": [("ชุดเริ่มต้น", "น้ำค้าง 150 เหรียญ ไม้ หิน และชุดมิ้นต์"), ("ที่ในเรือนเพาะ", "บลูมลิงผู้ช่วยเพิ่มอีกตัวตลอดไป"), ("บัตรผ่านกิจกรรม", "รางวัลทั้งหมดของกิจกรรมสัปดาห์นี้")],
 "vi": [("Gói khởi đầu", "150 sương, xu, gỗ, đá và diện mạo bạc hà"), ("Chỗ trong vườn ươm", "Thêm một Bloomling trợ thủ, mãi mãi"), ("Vé sự kiện", "Mọi phần thưởng của sự kiện tuần này")],
 "id": [("Paket pemula", "150 embun, koin, kayu, batu, tampilan mint"), ("Tempat pembibitan", "Satu Bloomling pembantu lagi, selamanya"), ("Pass event", "Semua hadiah event minggu ini")],
 "sv": [("Startpaket", "150 dagg, mynt, trä, sten och mintlooken"), ("Plantskoleplats", "En Bloomling-hjälpare till, för alltid"), ("Eventpass", "Alla belöningar i veckans event")],
}
_old_table = table


def table():
    out = _old_table()
    for pid in IDS2:
        out[pid] = []
    for loc, rows in L2.items():
        assert len(rows) == len(IDS2), loc
        for pid, (n, d) in zip(IDS2, rows):
            assert len(n) <= 30 and len(d) <= 45, (loc, pid, n, d, len(d))
            out[pid].append((loc, n, d))
    return out


# Donate 2 bundles (same order as IDS3). Name <= 30, description <= 45.
IDS3 = ["bloom.brave", "bloom.crafter", "bloom.digger", "bloom.islandpack", "bloom.friend", "bloom.level10", "bloom.level20"]
L3 = {
 "en-US": [("Brave Heart", "+2 hearts for good and 100 dew"), ("Jack of All Trades", "All buildings work twice as fast, for good"),
           ("Treasure Hunter", "Golden shovel: double treasure, 200 dew"), ("Island Within Reach", "Coins toward the next island and 100 dew"),
           ("Island Friend", "Friend gifts x2 for good, Bumble companion"), ("Level 10 Bundle", "Rose Garden look, 300 dew, wood and stone"),
           ("Level 20 Bundle", "Night look, Owlet companion, 800 dew")],
 "ru": [("Сердце смельчака", "+2 сердца навсегда и 100 росинок"), ("Мастер на все руки", "Все здания вдвое быстрее навсегда"),
        ("Кладоискатель", "Золотая лопата: клады ×2, 200 росинок"), ("Остров ближе", "Монеты на новый остров и 100 росинок"),
        ("Друг острова", "Подарки друзей ×2 и спутник Шмелик"), ("Набор 10 уровня", "Облик, 300 росинок, дерево и камень"),
        ("Набор 20 уровня", "Ночной облик, Совушка, 800 росинок")],
 "uk": [("Серце сміливця", "+2 серця назавжди і 100 росинок"), ("Майстер на всі руки", "Усі будівлі вдвічі швидші назавжди"),
        ("Шукач скарбів", "Золота лопата: скарби ×2, 200 росинок"), ("Острів ближче", "Монети на новий острів і 100 росинок"),
        ("Друг острова", "Подарунки друзів ×2 і супутник Джмелик"), ("Набір 10 рівня", "Образ, 300 росинок, дерево і камінь"),
        ("Набір 20 рівня", "Нічний образ, Совуня, 800 росинок")],
 "de-DE": [("Mutiges Herz", "+2 Herzen für immer und 100 Tau"), ("Alleskönner", "Alle Gebäude für immer doppelt so schnell"),
           ("Schatzsucher", "Goldene Schaufel: Schätze x2, 200 Tau"), ("Insel in Reichweite", "Münzen für die nächste Insel und 100 Tau"),
           ("Inselfreund", "Freundesgeschenke x2 und Begleiter Hummel"), ("Paket Stufe 10", "Rosengarten-Look, 300 Tau, Holz, Stein"),
           ("Paket Stufe 20", "Nacht-Look, Eulchen, 800 Tau")],
 "fr-FR": [("Cœur vaillant", "+2 cœurs pour toujours et 100 rosée"), ("Touche-à-tout", "Bâtiments deux fois plus rapides"),
           ("Chasseur de trésors", "Pelle dorée : trésors x2, 200 rosée"), ("L'île à portée", "Pièces pour la prochaine île, 100 rosée"),
           ("Ami de l'île", "Cadeaux d'amis x2 et compagnon Bourdon"), ("Pack niveau 10", "Look Roseraie, 300 rosée, bois, pierre"),
           ("Pack niveau 20", "Look Nuit, Hibou, 800 rosée")],
 "es-ES": [("Corazón valiente", "+2 corazones para siempre y 100 rocío"), ("Manitas", "Edificios el doble de rápidos"),
           ("Cazatesoros", "Pala dorada: tesoros x2, 200 rocío"), ("La isla al alcance", "Monedas para la próxima isla y 100 rocío"),
           ("Amigo de la isla", "Regalos de amigos x2 y Abejorro"), ("Pack de nivel 10", "Aspecto Rosaleda, 300 rocío y recursos"),
           ("Pack de nivel 20", "Aspecto Noche, Buhito, 800 rocío")],
 "es-MX": [("Corazón valiente", "+2 corazones para siempre y 100 rocío"), ("Todero", "Edificios el doble de rápidos"),
           ("Cazatesoros", "Pala dorada: tesoros x2, 200 rocío"), ("La isla al alcance", "Monedas para la próxima isla y 100 rocío"),
           ("Amigo de la isla", "Regalos de amigos x2 y Abejorro"), ("Paquete nivel 10", "Aspecto Rosaleda, 300 rocío y recursos"),
           ("Paquete nivel 20", "Aspecto Noche, Buhito, 800 rocío")],
 "it": [("Cuore coraggioso", "+2 cuori per sempre e 100 rugiada"), ("Tuttofare", "Edifici il doppio più veloci, per sempre"),
        ("Cacciatore di tesori", "Pala d'oro: tesori x2, 200 rugiada"), ("L'isola a portata", "Monete per la prossima isola e 100 rugiada"),
        ("Amico dell'isola", "Regali degli amici x2 e Bombo"), ("Pacchetto livello 10", "Aspetto Roseto, 300 rugiada e risorse"),
        ("Pacchetto livello 20", "Aspetto Notte, Gufetto, 800 rugiada")],
 "pt-BR": [("Coração valente", "+2 corações para sempre e 100 orvalho"), ("Faz-tudo", "Prédios duas vezes mais rápidos"),
           ("Caçador de tesouros", "Pá dourada: tesouros x2, 200 orvalho"), ("Ilha ao alcance", "Moedas para a próxima ilha e 100 orvalho"),
           ("Amigo da ilha", "Presentes de amigos x2 e Zangão"), ("Pacote nível 10", "Visual Roseiral, 300 orvalho e recursos"),
           ("Pacote nível 20", "Visual Noite, Corujinha, 800 orvalho")],
 "pt-PT": [("Coração valente", "+2 corações para sempre e 100 orvalho"), ("Faz-tudo", "Edifícios duas vezes mais rápidos"),
           ("Caçador de tesouros", "Pá dourada: tesouros x2, 200 orvalho"), ("Ilha ao alcance", "Moedas para a próxima ilha e 100 orvalho"),
           ("Amigo da ilha", "Presentes de amigos x2 e Zangão"), ("Pacote nível 10", "Visual Roseiral, 300 orvalho e recursos"),
           ("Pacote nível 20", "Visual Noite, Corujinha, 800 orvalho")],
 "nl-NL": [("Dapper hart", "+2 harten voor altijd en 100 dauw"), ("Manusje-van-alles", "Gebouwen voor altijd twee keer zo snel"),
           ("Schatzoeker", "Gouden schep: schatten x2, 200 dauw"), ("Eiland binnen bereik", "Munten voor het volgende eiland, 100 dauw"),
           ("Eilandvriend", "Cadeaus van vrienden x2 en Hommel"), ("Pakket level 10", "Rozentuin-look, 300 dauw, hout, steen"),
           ("Pakket level 20", "Nacht-look, Uiltje, 800 dauw")],
 "pl": [("Dzielne serce", "+2 serca na zawsze i 100 rosy"), ("Złota rączka", "Budynki dwa razy szybsze na zawsze"),
        ("Poszukiwacz skarbów", "Złota łopata: skarby x2, 200 rosy"), ("Wyspa w zasięgu", "Monety na następną wyspę i 100 rosy"),
        ("Przyjaciel wyspy", "Prezenty przyjaciół x2 i Trzmielik"), ("Pakiet poziomu 10", "Wygląd Różany ogród, 300 rosy, surowce"),
        ("Pakiet poziomu 20", "Wygląd Nocny, Sówka, 800 rosy")],
 "tr": [("Cesur kalp", "Kalıcı +2 kalp ve 100 çiy"), ("Her işin ustası", "Binalar kalıcı olarak iki kat hızlı"),
        ("Hazine avcısı", "Altın kürek: hazine x2, 200 çiy"), ("Ada yakında", "Sonraki ada için altın ve 100 çiy"),
        ("Ada dostu", "Arkadaş hediyeleri x2 ve Bombus"), ("Seviye 10 paketi", "Gül Bahçesi görünümü, 300 çiy, kaynak"),
        ("Seviye 20 paketi", "Gece görünümü, Baykuşçuk, 800 çiy")],
 "ja": [("勇気のハート", "ずっとハート+2、しずく100"), ("なんでも屋", "建物がずっと2倍速く"),
        ("トレジャーハンター", "金のシャベル:お宝2倍、しずく200"), ("島がもうすぐ", "次の島のためのコインとしずく100"),
        ("島の友だち", "友だちのプレゼント2倍とおともブンブ"), ("レベル10セット", "バラ園の見た目、しずく300、木と石"),
        ("レベル20セット", "夜の見た目、フクロウ、しずく800")],
 "ko": [("용감한 마음", "영구 하트 +2와 이슬 100"), ("만능 장인", "모든 건물 영구 두 배 속도"),
        ("보물 사냥꾼", "황금 삽: 보물 두 배, 이슬 200"), ("섬이 가까이", "다음 섬을 위한 코인과 이슬 100"),
        ("섬의 친구", "친구 선물 두 배와 동료 붕붕"), ("10레벨 패키지", "장미 정원 외형, 이슬 300, 나무와 돌"),
        ("20레벨 패키지", "밤 외형, 부엉이, 이슬 800")],
 "zh-Hans": [("勇敢之心", "永久+2颗心和100露珠"), ("全能工匠", "所有建筑永久双倍速度"),
             ("寻宝人", "金铲子：宝藏翻倍，200露珠"), ("小岛近在眼前", "下一座岛的金币和100露珠"),
             ("小岛之友", "朋友礼物翻倍和伙伴嗡嗡"), ("10级礼包", "玫瑰园造型、300露珠、木头和石头"),
             ("20级礼包", "夜晚造型、小猫头鹰、800露珠")],
 "zh-Hant": [("勇敢之心", "永久+2顆心和100露珠"), ("全能工匠", "所有建築永久雙倍速度"),
             ("尋寶人", "金鏟子：寶藏加倍，200露珠"), ("小島近在眼前", "下一座島的金幣和100露珠"),
             ("小島之友", "朋友禮物加倍和夥伴嗡嗡"), ("10級禮包", "玫瑰園造型、300露珠、木頭和石頭"),
             ("20級禮包", "夜晚造型、小貓頭鷹、800露珠")],
 "ar-SA": [("قلب شجاع", "+2 قلب للأبد و100 ندى"), ("صاحب الصنعة", "كل المباني أسرع بمرتين للأبد"),
           ("صائد الكنوز", "مجرفة ذهبية: كنوز ×2 و200 ندى"), ("الجزيرة في متناولك", "عملات للجزيرة التالية و100 ندى"),
           ("صديق الجزيرة", "هدايا الأصدقاء ×2 والرفيق طنّان"), ("حزمة المستوى 10", "مظهر حديقة الورد و300 ندى وموارد"),
           ("حزمة المستوى 20", "المظهر الليلي والبومة و800 ندى")],
 "th": [("หัวใจกล้าหาญ", "+2 หัวใจถาวร และน้ำค้าง 100"), ("ช่างสารพัด", "ทุกอาคารเร็วขึ้นสองเท่าถาวร"),
        ("นักล่าสมบัติ", "พลั่วทอง: สมบัติ ×2 น้ำค้าง 200"), ("เกาะใกล้เข้ามา", "เหรียญสำหรับเกาะถัดไปและน้ำค้าง 100"),
        ("เพื่อนแห่งเกาะ", "ของขวัญเพื่อน ×2 และผึ้งน้อย"), ("แพ็กเลเวล 10", "ชุดสวนกุหลาบ น้ำค้าง 300 ไม้และหิน"),
        ("แพ็กเลเวล 20", "ชุดราตรี นกฮูกน้อย น้ำค้าง 800")],
 "vi": [("Trái tim dũng cảm", "+2 tim vĩnh viễn và 100 sương"), ("Đa năng", "Mọi công trình nhanh gấp đôi mãi mãi"),
        ("Thợ săn kho báu", "Xẻng vàng: kho báu x2, 200 sương"), ("Đảo trong tầm tay", "Xu cho đảo tiếp theo và 100 sương"),
        ("Bạn của đảo", "Quà bạn bè x2 và Ong Nghệ"), ("Gói cấp 10", "Vườn Hồng, 300 sương, gỗ và đá"),
        ("Gói cấp 20", "Trang phục Đêm, Cú Nhỏ, 800 sương")],
 "id": [("Hati pemberani", "+2 hati selamanya dan 100 embun"), ("Serba bisa", "Semua bangunan 2x lebih cepat selamanya"),
        ("Pemburu harta", "Sekop emas: harta x2, 200 embun"), ("Pulau makin dekat", "Koin untuk pulau berikutnya, 100 embun"),
        ("Teman pulau", "Hadiah teman x2 dan teman Kumbang"), ("Paket level 10", "Taman Mawar, 300 embun, kayu, batu"),
        ("Paket level 20", "Tampilan Malam, Burung Hantu, 800 embun")],
 "sv": [("Modigt hjärta", "+2 hjärtan för alltid och 100 dagg"), ("Tusenkonstnär", "Alla byggnader dubbelt så snabba"),
        ("Skattjägare", "Gyllene spade: skatter x2, 200 dagg"), ("Ön inom räckhåll", "Mynt till nästa ö och 100 dagg"),
        ("Övän", "Vängåvor x2 och följeslagaren Humla"), ("Paket nivå 10", "Rosengård-stil, 300 dagg, trä och sten"),
        ("Paket nivå 20", "Natt-stil, Ugglan, 800 dagg")],
}
_old_table2 = table


def table():
    out = _old_table2()
    for pid in IDS3:
        out[pid] = []
    for loc, rows in L3.items():
        assert len(rows) == len(IDS3), loc
        for pid, (n, d) in zip(IDS3, rows):
            assert len(n) <= 30 and len(d) <= 45, (loc, pid, n, d, len(d))
            out[pid].append((loc, n, d))
    return out
