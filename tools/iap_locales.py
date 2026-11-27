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
 "en-US": [("Starter Pack", "150 dew, a chest and the Mint look"), ("Nursery Slot", "One more Bloomling helper, forever"), ("Event Pass", "All rewards of this week's event")],
 "ru": [("Стартовый набор", "150 росинок, сундук и мятный облик"), ("Место в питомнике", "Ещё один блумлинг-помощник навсегда"), ("Пропуск события", "Все награды события этой недели")],
 "uk": [("Стартовий набір", "150 росинок, скриня й м'ятний образ"), ("Місце в розсаднику", "Ще один блумлінг-помічник назавжди"), ("Перепустка події", "Усі нагороди події цього тижня")],
 "de-DE": [("Starterpaket", "150 Tau, eine Truhe und der Minz-Look"), ("Gärtnerei-Platz", "Ein weiterer Bloomling-Helfer, für immer"), ("Eventpass", "Alle Belohnungen des Wochenevents")],
 "fr-FR": [("Pack de départ", "150 rosée, un coffre et le look menthe"), ("Place à la pépinière", "Un Bloomling de plus, pour toujours"), ("Pass d'événement", "Toutes les récompenses de la semaine")],
 "es-ES": [("Pack de inicio", "150 rocío, un cofre y el aspecto menta"), ("Hueco en el vivero", "Un Bloomling ayudante más, para siempre"), ("Pase del evento", "Todas las recompensas del evento semanal")],
 "es-MX": [("Paquete inicial", "150 rocío, un cofre y el aspecto menta"), ("Lugar en el vivero", "Un Bloomling ayudante más, para siempre"), ("Pase del evento", "Todas las recompensas del evento semanal")],
 "it": [("Pacchetto iniziale", "150 rugiada, un forziere e look menta"), ("Posto nel vivaio", "Un Bloomling aiutante in più, per sempre"), ("Pass evento", "Tutte le ricompense dell'evento")],
 "pt-BR": [("Pacote inicial", "150 orvalho, um baú e o visual menta"), ("Vaga no viveiro", "Mais um Bloomling ajudante, para sempre"), ("Passe do evento", "Todas as recompensas do evento da semana")],
 "pt-PT": [("Pacote inicial", "150 orvalho, um baú e o visual menta"), ("Lugar no viveiro", "Mais um Bloomling ajudante, para sempre"), ("Passe do evento", "Todas as recompensas do evento da semana")],
 "nl-NL": [("Starterspakket", "150 dauw, een kist en de muntgroene look"), ("Kwekerijplek", "Nog een Bloomling-helper, voor altijd"), ("Eventpas", "Alle beloningen van het weekevent")],
 "pl": [("Zestaw startowy", "150 rosy, skrzynia i miętowy wygląd"), ("Miejsce w szkółce", "Jeszcze jeden Bloomling na zawsze"), ("Karnet wydarzenia", "Wszystkie nagrody wydarzenia tygodnia")],
 "tr": [("Başlangıç paketi", "150 çiy, bir sandık ve nane görünümü"), ("Fidanlık yeri", "Bir Bloomling yardımcı daha, sonsuza dek"), ("Etkinlik bileti", "Bu haftaki etkinliğin tüm ödülleri")],
 "ja": [("スターターパック", "しずく150、宝箱、ミントの見た目"), ("苗床の追加枠", "ブルームリングの仲間がずっと1匹増える"), ("イベントパス", "今週のイベントの報酬すべて")],
 "ko": [("스타터 팩", "이슬 150, 상자, 민트 외형"), ("묘목장 자리", "블룸링 도우미 한 마리 영구 추가"), ("이벤트 패스", "이번 주 이벤트의 모든 보상")],
 "zh-Hans": [("新手礼包", "150露珠、一个宝箱和薄荷外观"), ("苗圃位置", "永久多一只花灵助手"), ("活动通行证", "本周活动的全部奖励")],
 "zh-Hant": [("新手禮包", "150露珠、一個寶箱和薄荷外觀"), ("苗圃位置", "永久多一隻花靈助手"), ("活動通行證", "本週活動的全部獎勵")],
 "ar-SA": [("حزمة البداية", "150 ندى وصندوق ومظهر نعناعي"), ("مكان في المشتل", "مساعد بلوملينغ إضافي إلى الأبد"), ("تذكرة الحدث", "كل مكافآت حدث هذا الأسبوع")],
 "th": [("ชุดเริ่มต้น", "น้ำค้าง 150 หีบ และชุดสีมิ้นต์"), ("ที่ในเรือนเพาะ", "บลูมลิงผู้ช่วยเพิ่มอีกตัวตลอดไป"), ("บัตรผ่านกิจกรรม", "รางวัลทั้งหมดของกิจกรรมสัปดาห์นี้")],
 "vi": [("Gói khởi đầu", "150 sương, một rương và diện mạo bạc hà"), ("Chỗ trong vườn ươm", "Thêm một Bloomling trợ thủ, mãi mãi"), ("Vé sự kiện", "Mọi phần thưởng của sự kiện tuần này")],
 "id": [("Paket pemula", "150 embun, peti, dan tampilan mint"), ("Tempat pembibitan", "Satu Bloomling pembantu lagi, selamanya"), ("Pass event", "Semua hadiah event minggu ini")],
 "sv": [("Startpaket", "150 dagg, en kista och mintlooken"), ("Plantskoleplats", "En Bloomling-hjälpare till, för alltid"), ("Eventpass", "Alla belöningar i veckans event")],
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
