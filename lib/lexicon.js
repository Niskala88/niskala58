// Offline fallback lexicon. Three lenses per symbol, each bilingual
// (id/en) so the reading follows the UI language toggle instead of
// being locked to one language per lens.
// Used when no ANTHROPIC_API_KEY is set or the API call fails.

export const LEXICON = {
  air: {
    match: ["air", "water", "sungai", "river", "laut", "sea", "ocean", "hujan", "rain", "banjir", "flood", "berenang", "swim"],
    theme: "emotion",
    jung: {
      en: "Water is the classic image of the unconscious itself. Clear water suggests you can currently see into your own depths; murky or flooding water suggests emotion rising faster than the ego can integrate it.",
      id: "Air adalah citra klasik dari alam bawah sadar itu sendiri. Air jernih artinya kamu lagi bisa ngeliat ke dalam diri sendiri dengan jelas; air keruh atau banjir artinya emosi lagi naik lebih cepat dari yang bisa dicerna egomu.",
    },
    primbon: {
      id: "Air jernih dalam primbon umumnya pertanda rezeki dan kejernihan pikiran akan datang. Air keruh atau banjir memperingatkan gosip atau urusan yang meluap — jaga ucapan beberapa hari ke depan.",
      en: "Clear water in primbon generally signals fortune and clarity of mind on the way. Murky water or floods warn of gossip or matters overflowing — watch your words for the next few days.",
    },
    islamic: {
      en: "Clear water in the Ibn Sirin tradition is often read as knowledge, purity of livelihood, or blessings. Turbid water can indicate trials or unclear matters — a prompt for patience and prayer for clarity.",
      id: "Air jernih dalam tradisi Ibn Sirin sering dibaca sebagai ilmu, rezeki yang bersih, atau berkah. Air keruh bisa jadi pertanda ujian atau urusan yang belum jelas — isyarat untuk sabar dan berdoa minta kejelasan.",
    },
  },
  ular: {
    match: ["ular", "snake", "serpent"],
    theme: "transformation",
    jung: {
      en: "The snake carries transformation and instinctual energy — the part of you that sheds skins. A calm snake that doesn't strike often marks a transition you are ready for, not a threat.",
      id: "Ular bawa energi transformasi dan naluri — bagian dari dirimu yang lagi ganti kulit. Ular tenang yang nggak nyerang biasanya nandain transisi yang kamu udah siap hadapin, bukan ancaman.",
    },
    primbon: {
      id: "Ular dalam primbon sering dibaca sebagai kedatangan jodoh, tamu penting, atau rezeki yang tidak terduga — terutama ular yang tidak menggigit. Ular putih khususnya dianggap pertanda baik.",
      en: "In primbon, a snake is often read as an incoming match, an important guest, or unexpected fortune — especially one that doesn't bite. A white snake is considered especially auspicious.",
    },
    islamic: {
      en: "Snakes are frequently interpreted as an enemy or a trial; however a snake that causes no harm may point to an adversary whose plans dissolve, or wealth with hidden responsibility attached.",
      id: "Ular sering ditafsirkan sebagai musuh atau ujian; tapi ular yang tidak menyakiti bisa menandakan lawan yang rencananya bubar, atau rezeki yang ada tanggung jawab tersembunyi di baliknya.",
    },
  },
  gigi: {
    match: ["gigi", "teeth", "tooth", "copot", "tanggal"],
    theme: "anxiety",
    jung: {
      en: "Losing teeth often accompanies anxiety about power, appearance, or a life stage ending — the bite you fear losing. Ask what in waking life feels like it is loosening.",
      id: "Gigi copot biasanya nemenin kecemasan soal kekuatan, penampilan, atau babak hidup yang berakhir — gigitan yang kamu takut hilang. Tanya diri sendiri, apa di kehidupan nyata yang kerasa mulai longgar.",
    },
    primbon: {
      id: "Gigi copot dalam primbon secara tradisional dikaitkan dengan kabar tentang keluarga — gigi atas untuk yang dituakan, gigi bawah untuk yang lebih muda. Dibaca sebagai isyarat untuk menghubungi rumah.",
      en: "In primbon, falling teeth traditionally connect to news about family — upper teeth for elders, lower teeth for younger relatives. Read as a nudge to reach out home.",
    },
    islamic: {
      en: "Teeth in the Ibn Sirin tradition map to household and kin. A falling tooth can signal news concerning relatives; without pain or blood the reading is considerably softened.",
      id: "Gigi dalam tradisi Ibn Sirin dikaitkan dengan keluarga dan sanak saudara. Gigi tanggal bisa jadi pertanda kabar soal kerabat; kalau nggak sakit atau berdarah, tafsirnya jauh lebih ringan.",
    },
  },
  terbang: {
    match: ["terbang", "fly", "flying", "melayang", "float"],
    theme: "ambition",
    jung: {
      en: "Flight is liberation from a constraint — or inflation, rising above a problem instead of through it. Note whether the flying felt free or fleeing.",
      id: "Terbang adalah pembebasan dari suatu batasan — atau bisa juga inflasi ego, naik di atas masalah bukannya nembus lewat masalahnya. Perhatiin, terbangnya kerasa bebas apa kabur.",
    },
    primbon: {
      id: "Terbang dalam mimpi sering dibaca sebagai naiknya derajat: kabar baik soal pekerjaan, status, atau cita-cita yang mulai terangkat.",
      en: "Flying in a dream is often read as a rise in standing: good news about work, status, or a goal starting to lift off.",
    },
    islamic: {
      en: "Flying can signify travel, elevation in rank, or ambition; flying too high without direction may caution against wishful plans not tied to effort.",
      id: "Terbang bisa menandakan perjalanan, kenaikan pangkat, atau ambisi; terbang terlalu tinggi tanpa arah bisa jadi peringatan soal rencana yang nggak dibarengi usaha nyata.",
    },
  },
  hamil: {
    match: ["hamil", "pregnant", "pregnancy", "bayi", "baby", "melahirkan", "birth"],
    theme: "transformation",
    jung: {
      en: "Pregnancy is the psyche gestating something new — a project, identity, or capacity not yet ready to be seen. Birth dreams mark the arrival of what was being prepared in the dark.",
      id: "Hamil adalah gambaran jiwa lagi mengandung sesuatu yang baru — proyek, identitas, atau kapasitas yang belum siap keliatan. Mimpi melahirkan nandain kedatangan hal yang selama ini disiapin diam-diam.",
    },
    primbon: {
      id: "Mimpi hamil atau bayi umumnya pertanda rezeki baru atau permulaan yang membawa tanggung jawab. Sering muncul menjelang usaha atau babak hidup baru.",
      en: "Dreaming of pregnancy or a baby generally signals new fortune or a beginning that carries responsibility — often arriving right before a new venture or life chapter.",
    },
    islamic: {
      en: "Pregnancy in dreams is often read as increase — of provision, of concerns, or of a matter growing in one's life. Context and the dreamer's state determine which.",
      id: "Hamil dalam mimpi sering dibaca sebagai pertambahan — bisa rezeki, bisa juga beban pikiran, atau urusan yang lagi berkembang dalam hidup. Konteks dan keadaan si pemimpi yang menentukan mana yang berlaku.",
    },
  },
  rumah: {
    match: ["rumah", "house", "home", "kamar", "room", "pintu", "door"],
    theme: "security",
    jung: {
      en: "The house is the self; its rooms are aspects of your psyche. Discovering new rooms means discovering unlived capacities. The condition of the house mirrors your inner state.",
      id: "Rumah adalah representasi diri; kamar-kamarnya adalah sisi-sisi dari jiwamu. Nemuin kamar baru artinya nemuin kapasitas yang belum pernah dijalanin. Kondisi rumah nyerminin keadaan batinmu.",
    },
    primbon: {
      id: "Rumah baru atau rumah bersih dibaca sebagai datangnya ketentraman dan rezeki; rumah rusak mengisyaratkan ada urusan keluarga yang perlu dibereskan.",
      en: "A new or clean house is read as incoming peace and fortune; a broken-down house signals family matters that need sorting out.",
    },
    islamic: {
      en: "A house often represents the dreamer's worldly state or spouse; entering a beautiful unknown house may signal blessings, while a crumbling one calls for attention to one's affairs.",
      id: "Rumah sering mewakili keadaan duniawi si pemimpi atau pasangannya; masuk ke rumah asing yang indah bisa jadi pertanda berkah, sedangkan rumah yang runtuh mengisyaratkan perlu perhatian pada urusan pribadi.",
    },
  },
  kejar: {
    match: ["kejar", "dikejar", "chase", "chased", "lari", "run", "running"],
    theme: "anxiety",
    jung: {
      en: "Being chased is the shadow demanding audience — a feeling or truth you keep outrunning. The pursuer usually weakens the moment you turn and look at it.",
      id: "Dikejar adalah bayangan (shadow) yang minta didengar — perasaan atau kebenaran yang terus kamu hindari. Si pengejar biasanya melemah begitu kamu balik badan dan ngeliatnya langsung.",
    },
    primbon: {
      id: "Dikejar dalam primbon sering dimaknai adanya persoalan yang belum selesai atau orang yang menaruh maksud — isyarat untuk waspada tapi tidak takut.",
      en: "Being chased in primbon often means an unresolved matter, or someone with an agenda toward you — a nudge to stay alert, not to be afraid.",
    },
    islamic: {
      en: "Being pursued may reflect an unresolved obligation or fear; escaping safely is generally read as relief from difficulty by God's leave.",
      id: "Dikejar bisa mencerminkan kewajiban yang belum tuntas atau rasa takut; berhasil lolos umumnya dibaca sebagai keringanan dari kesulitan, insyaallah.",
    },
  },
  mati: {
    match: ["mati", "meninggal", "death", "die", "dead", "jenazah", "funeral"],
    theme: "transformation",
    jung: {
      en: "Death in dreams is almost never literal — it is the end of a chapter, identity, or attachment, clearing ground for what follows. Grief in the dream honors what is completing.",
      id: "Kematian dalam mimpi hampir nggak pernah harfiah — itu adalah akhir dari satu babak, identitas, atau keterikatan, ngebersihin ruang buat yang berikutnya. Sedih dalam mimpi adalah bentuk penghormatan buat yang lagi selesai.",
    },
    primbon: {
      id: "Mimpi kematian justru sering dibaca terbalik: panjang umur bagi yang 'meninggal' dalam mimpi, atau akan datangnya perubahan besar yang membawa kebaikan.",
      en: "Death dreams are often read in reverse: long life for whoever 'died' in the dream, or a major change bringing good coming your way.",
    },
    islamic: {
      en: "Death of a living person in a dream is frequently interpreted as long life for them, or as repentance and a turning point in the dreamer's own path.",
      id: "Kematian orang yang masih hidup dalam mimpi sering ditafsirkan sebagai panjang umur buat orang itu, atau sebagai taubat dan titik balik dalam perjalanan si pemimpi sendiri.",
    },
  },
  jatuh: {
    match: ["jatuh", "falling", "fall", "terjatuh", "jatoh"],
    theme: "anxiety",
    jung: {
      en: "Falling is the ego losing its footing — a loss of control you haven't consciously admitted yet. It often shows up right when you're gripping too tightly somewhere in waking life.",
      id: "Jatuh adalah ego yang kehilangan pijakan — kehilangan kendali yang belum kamu akui secara sadar. Sering muncul justru pas kamu lagi genggam sesuatu terlalu erat di dunia nyata.",
    },
    primbon: {
      id: "Mimpi jatuh dalam primbon sering dikaitkan dengan kekhawatiran akan kehilangan posisi, jabatan, atau kepercayaan — isyarat untuk berhati-hati dalam mengambil keputusan.",
      en: "Falling in primbon is often tied to worry about losing a position, status, or someone's trust — a nudge to be careful with upcoming decisions.",
    },
    islamic: {
      en: "Falling can point to a decline in status or a warning against overreach; landing safely often softens the reading into a lesson rather than a loss.",
      id: "Jatuh bisa menandakan penurunan status atau peringatan agar tidak berlebihan; kalau mendarat dengan selamat, tafsirnya biasanya melunak jadi pelajaran, bukan kerugian.",
    },
  },
  telanjang: {
    match: ["telanjang", "naked", "nude", "bugil"],
    theme: "exposure",
    jung: {
      en: "Nakedness in dreams exposes the gap between how you present yourself and how you fear being seen. It surfaces when you feel judged, or when you're finally ready to stop hiding something.",
      id: "Telanjang dalam mimpi ngebuka jarak antara gimana kamu nampilin diri dan gimana kamu takut diliat. Muncul pas kamu ngerasa dihakimi, atau pas kamu akhirnya siap berhenti nyembunyiin sesuatu.",
    },
    primbon: {
      id: "Mimpi telanjang di depan umum dalam primbon sering dibaca sebagai rasa cemas akan aib atau rahasia yang mungkin terbongkar — bukan pertanda buruk, lebih ke pengingat untuk jujur lebih dulu.",
      en: "Being naked in public in primbon is often read as anxiety about a secret or shame that might come out — not a bad omen so much as a nudge to be honest first, before it's forced out of you.",
    },
    islamic: {
      en: "Exposure in a dream can point to a hidden matter close to becoming known; handled with humility, it's read as a prompt toward honesty rather than a threat.",
      id: "Ketelanjangan dalam mimpi bisa menandakan sesuatu yang tersembunyi hampir terungkap; kalau disikapi dengan rendah hati, ini dibaca sebagai dorongan untuk jujur, bukan ancaman.",
    },
  },
  ujian: {
    match: ["ujian", "exam", "test", "tes", "sekolah", "school", "kuliah"],
    theme: "anxiety",
    jung: {
      en: "Exam dreams are the psyche auditing itself — a fear of being measured and found lacking, often triggered by real evaluation happening in waking life, even informally.",
      id: "Mimpi ujian adalah jiwa lagi ngaudit diri sendiri — takut diukur dan dianggap kurang, sering dipicu penilaian nyata yang lagi terjadi di kehidupan sadar, bahkan yang informal sekalipun.",
    },
    primbon: {
      id: "Mimpi ujian atau sekolah dalam primbon sering muncul saat seseorang sedang diuji kesabarannya di dunia nyata — pertanda untuk tetap tenang menghadapi penilaian orang lain.",
      en: "Exam or school dreams in primbon often surface when someone's patience is being genuinely tested in real life — a sign to stay calm under others' judgment.",
    },
    islamic: {
      en: "Being tested in a dream often mirrors a real trial of patience or competence; performing calmly in the dream is read as reassurance about handling the real one.",
      id: "Diuji dalam mimpi sering mencerminkan ujian kesabaran atau kemampuan yang nyata; tampil tenang dalam mimpi dibaca sebagai jaminan bahwa ujian aslinya bisa dihadapi dengan baik.",
    },
  },
  uang: {
    match: ["uang", "money", "emas", "gold", "harta", "treasure", "kaya"],
    theme: "fortune",
    jung: {
      en: "Money in dreams rarely means money — it's a symbol of psychic value, self-worth, or exchanged energy. Finding it unexpectedly can mark a moment of recognizing your own worth.",
      id: "Uang dalam mimpi jarang beneran soal uang — itu simbol nilai batin, harga diri, atau energi yang dipertukarkan. Nemuin uang tak terduga bisa nandain momen kamu akhirnya sadar akan nilai dirimu sendiri.",
    },
    primbon: {
      id: "Mimpi menemukan uang atau emas dalam primbon umumnya pertanda rezeki, tapi juga peringatan untuk tidak sombong — rezeki dalam mimpi kadang datang dalam bentuk bukan uang di dunia nyata.",
      en: "Finding money or gold in a dream in primbon generally signals fortune, but also a warning against arrogance — the fortune promised sometimes arrives in a form other than money in waking life.",
    },
    islamic: {
      en: "Gold or money in a dream can represent provision or a burden depending on context; carrying it with ease is read more favorably than struggling under its weight.",
      id: "Emas atau uang dalam mimpi bisa mewakili rezeki atau justru beban, tergantung konteksnya; membawanya dengan ringan dibaca lebih baik daripada tertatih-tatih memikulnya.",
    },
  },
  api: {
    match: ["api", "fire", "kebakaran", "terbakar", "burning"],
    theme: "transformation",
    jung: {
      en: "Fire is raw transformative energy — passion, anger, or destruction that clears the way for renewal. Whether it feels purifying or threatening in the dream tells you which one it is.",
      id: "Api adalah energi transformatif mentah — gairah, amarah, atau kehancuran yang membuka jalan buat pembaruan. Kerasanya memurnikan atau mengancam di mimpi itu, itu yang nentuin mana yang berlaku.",
    },
    primbon: {
      id: "Api dalam primbon bisa bermakna ganda: rezeki yang berkobar kalau apinya terkendali, atau pertanda emosi yang perlu diredam kalau apinya mengamuk tak terkendali.",
      en: "Fire in primbon can go two ways: blazing fortune if the fire is contained, or a sign that emotions need cooling down if the fire rages out of control.",
    },
    islamic: {
      en: "Fire's reading swings on control — a contained flame can signal warmth, knowledge, or influence, while a raging fire warns against anger left unchecked.",
      id: "Tafsir api tergantung terkendali atau tidaknya — nyala yang terjaga bisa menandakan kehangatan, ilmu, atau pengaruh, sedangkan api yang mengamuk memperingatkan soal amarah yang dibiarkan tak terkendali.",
    },
  },
  mobil: {
    match: ["mobil", "car", "kecelakaan", "crash", "tabrakan", "motor", "kendaraan"],
    theme: "control",
    jung: {
      en: "Vehicles in dreams represent how much control you feel over the direction of your life. A crash or loss of brakes often mirrors a real decision that feels out of your hands.",
      id: "Kendaraan dalam mimpi ngewakilin seberapa besar kendali yang kamu rasa punya atas arah hidupmu. Kecelakaan atau rem blong biasanya nyerminin keputusan nyata yang kerasa di luar kendalimu.",
    },
    primbon: {
      id: "Mimpi kecelakaan kendaraan dalam primbon sering dibaca sebagai peringatan untuk lebih berhati-hati dalam mengambil langkah besar, bukan ramalan kecelakaan sungguhan.",
      en: "A vehicle-crash dream in primbon is often read as a warning to be more careful with a big upcoming step, not a literal prediction of an accident.",
    },
    islamic: {
      en: "A vehicle out of control in a dream can reflect anxiety about a path taken without full agreement from the heart — worth pausing to check the direction before continuing.",
      id: "Kendaraan yang lepas kendali dalam mimpi bisa mencerminkan kecemasan soal jalan yang diambil tanpa kesepakatan penuh dari hati — layak dijeda dulu buat ngecek arahnya sebelum lanjut.",
    },
  },
  cermin: {
    match: ["cermin", "mirror", "bayangan", "reflection"],
    theme: "reflection",
    jung: {
      en: "Mirrors in dreams are the self observing the self — what you see reflected, especially if it's distorted or unfamiliar, is the part of you seeking recognition.",
      id: "Cermin dalam mimpi adalah diri yang lagi ngamatin diri sendiri — apa yang keliatan di pantulannya, apalagi kalau terdistorsi atau asing, itu bagian dari dirimu yang lagi nyari pengakuan.",
    },
    primbon: {
      id: "Cermin dalam primbon sering dikaitkan dengan introspeksi diri — bayangan yang tidak sesuai kenyataan menandakan ada sisi diri yang belum sepenuhnya diterima.",
      en: "Mirrors in primbon are often tied to self-introspection — a reflection that doesn't match reality signals a part of yourself not yet fully accepted.",
    },
    islamic: {
      en: "A mirror often stands for self-knowledge or how one is perceived by others; a clear reflection is favorable, a cracked or unclear one calls for self-examination.",
      id: "Cermin sering mewakili pengenalan diri atau bagaimana seseorang dipandang orang lain; pantulan yang jernih itu baik, yang retak atau buram mengisyaratkan perlunya introspeksi diri.",
    },
  },
  gunung: {
    match: ["gunung", "mountain", "mendaki", "climbing", "puncak", "summit"],
    theme: "ambition",
    jung: {
      en: "Climbing represents the individuation journey — the slow ascent toward a fuller self. Struggle on the climb usually mirrors real effort you're putting toward a goal.",
      id: "Mendaki mewakili perjalanan individuasi — pendakian pelan menuju diri yang lebih utuh. Kesulitan di jalan biasanya nyerminin usaha nyata yang lagi kamu curahin buat satu tujuan.",
    },
    primbon: {
      id: "Mendaki gunung dalam primbon sering dibaca sebagai perjalanan menuju cita-cita yang tinggi — sampai di puncak pertanda keberhasilan, terhenti di tengah jalan pertanda perlu kesabaran lebih.",
      en: "Climbing a mountain in primbon is often read as the journey toward a lofty goal — reaching the summit signals success, getting stuck partway signals needing more patience.",
    },
    islamic: {
      en: "Ascending a mountain can represent striving toward a high goal or spiritual elevation; reaching the top is read as attainment, struggling partway as a call for patience.",
      id: "Mendaki gunung bisa mewakili perjuangan menuju tujuan tinggi atau kenaikan spiritual; sampai puncak dibaca sebagai pencapaian, tersendat di tengah jalan sebagai seruan untuk bersabar.",
    },
  },
  laut: {
    match: ["laut", "ombak", "tsunami", "gelombang", "wave", "storm", "badai", "petir", "lightning"],
    theme: "overwhelm",
    jung: {
      en: "Storms and great waves are overwhelming emotion breaking through the surface — feelings too large to have been consciously processed while awake.",
      id: "Badai dan gelombang besar adalah emosi yang membludak ke permukaan — perasaan yang terlalu besar buat udah bisa diolah secara sadar pas kamu bangun.",
    },
    primbon: {
      id: "Ombak besar atau badai dalam primbon sering menandakan gejolak emosi atau masalah besar yang sedang atau akan dihadapi — bukan untuk ditakuti, tapi untuk disiapkan.",
      en: "A great wave or storm in primbon often signals emotional turmoil or a big problem being faced or about to be — not something to fear, but something to prepare for.",
    },
    islamic: {
      en: "A great wave or storm can reflect an overwhelming trial approaching; surviving it in the dream is often read as reassurance that it will pass.",
      id: "Gelombang besar atau badai bisa mencerminkan ujian besar yang mendekat; berhasil selamat dalam mimpi umumnya dibaca sebagai jaminan bahwa ujian itu akan berlalu.",
    },
  },
  nikah: {
    match: ["nikah", "wedding", "menikah", "kawin", "married", "pengantin"],
    theme: "union",
    jung: {
      en: "Weddings in dreams often symbolize a union within the self — integrating two opposing parts of your personality — more often than a literal relationship.",
      id: "Pernikahan dalam mimpi sering melambangkan penyatuan di dalam diri sendiri — dua sisi kepribadian yang berlawanan lagi digabungin — lebih sering daripada soal hubungan beneran.",
    },
    primbon: {
      id: "Mimpi pernikahan dalam primbon justru kadang dibaca terbalik sebagai isyarat kesedihan atau perpisahan sesaat — bukan larangan menikah, tapi pengingat untuk lebih waspada terhadap perasaan.",
      en: "A wedding dream in primbon is sometimes read in reverse, as a sign of temporary sadness or separation — not a ban on marrying, more a nudge to stay attentive to your feelings.",
    },
    islamic: {
      en: "A wedding dream can be read either way depending on tradition — sometimes union and joy, sometimes a caution about separation; context and feeling in the dream matter most.",
      id: "Mimpi pernikahan bisa dibaca dua arah tergantung tradisinya — kadang penyatuan dan kebahagiaan, kadang peringatan soal perpisahan; konteks dan perasaan dalam mimpi itu yang paling menentukan.",
    },
  },
  mantan: {
    match: ["mantan", "ex", "pacar lama", "old flame"],
    theme: "unfinished",
    jung: {
      en: "An ex appearing in dreams is rarely about them — it's about an unresolved quality they represented: freedom, safety, recklessness. Ask what that person meant, not who they were.",
      id: "Mantan yang muncul di mimpi jarang beneran soal mereka — itu soal kualitas yang mereka wakilin dan belum selesai: kebebasan, rasa aman, atau kenekatan. Tanya, apa arti orang itu buatmu, bukan siapa mereka.",
    },
    primbon: {
      id: "Mimpi tentang mantan dalam primbon sering muncul saat ada urusan lama yang belum benar-benar selesai di hati — bukan tanda harus balik, tapi tanda untuk benar-benar melepaskan.",
      en: "Dreaming of an ex in primbon often surfaces when old business isn't truly settled in the heart — not a sign to get back together, but a sign to genuinely let go.",
    },
    islamic: {
      en: "Encountering a past partner in a dream often points to unfinished emotional business rather than a sign to reconnect — closure, not reunion, is usually the deeper message.",
      id: "Bertemu mantan pasangan dalam mimpi sering menandakan urusan emosional yang belum tuntas, bukan isyarat untuk balikan — penutupan, bukan penyatuan kembali, biasanya pesan yang lebih dalam.",
    },
  },
  kunci: {
    match: ["kunci", "keys", "hilang", "lost", "lose", "kehilangan"],
    theme: "loss",
    jung: {
      en: "Losing something valuable in a dream, especially keys, mirrors a real fear of losing access — to control, to a relationship, to a version of yourself you've relied on.",
      id: "Kehilangan sesuatu yang berharga dalam mimpi, apalagi kunci, nyerminin ketakutan nyata akan kehilangan akses — ke kendali, ke hubungan, atau ke versi dirimu yang selama ini kamu andelin.",
    },
    primbon: {
      id: "Kehilangan barang dalam mimpi menurut primbon sering dikaitkan dengan kekhawatiran akan sesuatu yang berharga dalam hidup nyata — bisa jadi peringatan untuk lebih menjaga apa yang dimiliki.",
      en: "Losing an object in a dream in primbon is often tied to worry over something precious in real life — a possible nudge to take better care of what you already have.",
    },
    islamic: {
      en: "Losing an object in a dream can reflect anxiety over losing something valued in waking life; finding it again, even in a later dream, is read as reassurance.",
      id: "Kehilangan barang dalam mimpi bisa mencerminkan kecemasan akan kehilangan sesuatu yang berharga di dunia nyata; menemukannya lagi, bahkan di mimpi berikutnya, dibaca sebagai jaminan ketenangan.",
    },
  },
  hewan: {
    match: ["kucing", "cat", "anjing", "dog", "burung", "bird", "ikan", "fish", "laba-laba", "spider"],
    theme: "instinct",
    jung: {
      en: "Animals in dreams carry instinctual material the conscious mind hasn't integrated — their behavior toward you usually mirrors how you're treating your own instincts lately.",
      id: "Hewan dalam mimpi bawa muatan naluriah yang belum diintegrasiin sama pikiran sadar — sikap mereka ke kamu biasanya nyerminin gimana kamu memperlakukan nalurimu sendiri belakangan ini.",
    },
    primbon: {
      id: "Hewan dalam mimpi menurut primbon punya makna berbeda-beda tergantung jenisnya, tapi secara umum hewan yang jinak pertanda pertemanan atau rezeki, sedangkan yang mengancam pertanda perlu waspada pada seseorang di sekitar.",
      en: "Animals in primbon carry different meanings depending on the species, but broadly a gentle animal signals friendship or fortune, while a threatening one signals caution around someone nearby.",
    },
    islamic: {
      en: "Animals in dreams often represent people or character traits in the dreamer's life; a gentle animal suggests a good companion, while an aggressive one may point to caution around someone nearby.",
      id: "Hewan dalam mimpi sering mewakili orang atau sifat tertentu dalam hidup si pemimpi; hewan yang jinak menandakan teman baik, sedangkan yang agresif bisa jadi isyarat waspada pada seseorang di sekitar.",
    },
  },
  makan: {
    match: ["makan", "eating", "food", "makanan", "lapar", "hungry"],
    theme: "nourishment",
    jung: {
      en: "Eating in dreams is about what you're taking in — literally or emotionally. Feeling satisfied versus still hungry in the dream often mirrors how nourished you feel in real life right now.",
      id: "Makan dalam mimpi soal apa yang lagi kamu serap — secara harfiah maupun emosional. Kerasa kenyang atau masih lapar di mimpi biasanya nyerminin seberapa terisi kamu ngerasa di dunia nyata sekarang.",
    },
    primbon: {
      id: "Mimpi makan dalam primbon umumnya pertanda kecukupan rezeki, tapi makan tanpa merasa kenyang bisa jadi isyarat ada kebutuhan batin yang belum terpenuhi.",
      en: "Eating in a dream in primbon generally signals sufficient fortune, but eating without ever feeling full can signal an inner need that hasn't been met.",
    },
    islamic: {
      en: "Eating in a dream is generally read as provision arriving; the type and quality of food often color whether it's read as pure blessing or something requiring caution.",
      id: "Makan dalam mimpi umumnya dibaca sebagai datangnya rezeki; jenis dan kualitas makanannya sering menentukan apakah ini berkah murni atau sesuatu yang perlu diwaspadai.",
    },
  },
  darah: {
    match: ["darah", "blood", "luka", "wound", "berdarah", "bleeding"],
    theme: "vitality",
    jung: {
      en: "Blood in dreams marks vital energy — where it's lost or shed often points to where you feel depleted, wounded, or forced to give more of yourself than feels sustainable.",
      id: "Darah dalam mimpi nandain energi vital — di mana darahnya hilang atau tertumpah biasanya nunjuk ke bagian dirimu yang kerasa terkuras, terluka, atau dipaksa ngasih lebih dari yang berkelanjutan.",
    },
    primbon: {
      id: "Mimpi berdarah dalam primbon sering dibaca sebagai pertanda rezeki yang datang lewat usaha keras, bukan selalu pertanda buruk — meski tetap perlu introspeksi soal kesehatan.",
      en: "Bleeding in a dream in primbon is often read as fortune arriving through hard effort, not always a bad omen — though it's still worth checking in on your health.",
    },
    islamic: {
      en: "Blood in a dream can be read as unlawful or hard-earned gain depending on context, and sometimes as a call to reflect on one's actions rather than a literal warning.",
      id: "Darah dalam mimpi bisa dibaca sebagai keuntungan yang tidak halal atau hasil kerja keras tergantung konteksnya, dan kadang sebagai ajakan merenungi perbuatan diri sendiri, bukan peringatan harfiah.",
    },
  },
};

// Generic, mood-aware fallback when no specific symbol matches —
// the reading is never a dead end, just less specific. Bilingual.
const GENERIC = {
  jung: {
    default: { en: "No single symbol dominates this dream, which is itself worth noting — it suggests the material is more atmospheric than symbolic, closer to processing a mood than solving a specific conflict. Pay attention to how you felt on waking rather than what happened in the dream.",
      id: "Nggak ada satu simbol pun yang dominan di mimpi ini, dan itu sendiri patut diperhatiin — artinya materinya lebih atmosferik daripada simbolik, lebih ke ngolah suasana hati daripada nyelesain konflik spesifik. Perhatiin gimana perasaanmu pas bangun, bukan apa yang kejadian di mimpinya." },
    tenang: { en: "The calm quality of this dream suggests your unconscious isn't currently in conflict with itself — a rare, worth-noticing state. Let it be a baseline you can return to.",
      id: "Ketenangan di mimpi ini nandain alam bawah sadarmu lagi nggak konflik sama dirinya sendiri — kondisi langka yang layak diperhatiin. Jadiin ini titik acuan buat kamu balik lagi ke sana." },
    aneh: { en: "Strangeness in a dream without clear symbols often means the material is still being processed into shape — not every dream arrives pre-digested. Give it a day or two before trying to interpret it further.",
      id: "Keanehan di mimpi tanpa simbol jelas biasanya artinya materinya masih lagi diolah jadi bentuk — nggak semua mimpi dateng dalam kondisi udah rapi. Kasih waktu sehari-dua sebelum coba ditafsir lebih jauh." },
    takut: { en: "Fear without a clear cause in the dream often points to something diffuse in waking life — a background anxiety not yet attached to a specific object. Ask what's been unnamed lately.",
      id: "Rasa takut tanpa sebab jelas di mimpi biasanya nunjuk ke sesuatu yang masih kabur di kehidupan nyata — kecemasan latar belakang yang belum nemplok ke objek spesifik. Tanya, apa yang belum dinamain belakangan ini." },
    senang: { en: "Unclouded happiness in a dream, without an obvious cause, sometimes marks a genuine release the conscious mind hasn't caught up to yet. Trust it more than you'd trust it while awake.",
      id: "Kebahagiaan tanpa awan di mimpi, tanpa sebab jelas, kadang nandain kelegaan asli yang pikiran sadar belum nyampe ke sana. Percaya itu lebih dari yang biasanya kamu percaya pas kamu bangun." },
    sedih: { en: "Sadness in a dream without a clear trigger is often the psyche processing a loss the conscious mind hasn't fully acknowledged yet — even a small one.",
      id: "Kesedihan di mimpi tanpa pemicu jelas biasanya jiwa lagi ngolah kehilangan yang pikiran sadar belum sepenuhnya akuin — meski itu kehilangan yang kecil." },
    vivid: { en: "Unusually vivid dreams tend to happen during periods of heightened processing — big transitions, decisions, or unresolved tension. The vividness itself is the signal, more than any single image in it.",
      id: "Mimpi yang terasa sangat nyata biasanya muncul pas lagi ada pemrosesan intens — transisi besar, keputusan, atau ketegangan yang belum selesai. Kenyataannya itu sendiri sinyalnya, lebih dari gambar spesifik apa pun di dalamnya." },
  },
  primbon: {
    default: { id: "Nggak ada simbol spesifik yang cocok di leksikon, tapi dalam primbon, mimpi yang samar-samar begini biasanya dibaca lewat perasaan yang tersisa pas bangun, bukan lewat detail kejadiannya. Kalau perasaannya tenang, itu pertanda baik; kalau gelisah, coba lebih hati-hati beberapa hari ke depan.",
      en: "No specific symbol matched in the lexicon, but in primbon, a hazy dream like this is usually read through the feeling left over on waking, not the plot details. If the feeling was calm, that's a good sign; if uneasy, be a bit more careful the next few days." },
    tenang: { id: "Mimpi yang tenang dalam primbon umumnya pertanda hari-hari ke depan akan berjalan lancar tanpa gejolak besar.",
      en: "A calm dream in primbon generally signals smooth days ahead without major upheaval." },
    aneh: { id: "Mimpi yang terasa aneh atau nggak jelas dalam primbon sering dianggap 'mimpi kosong' — bunga tidur biasa, bukan pertanda apa-apa. Nggak semua mimpi perlu ditafsir.",
      en: "A strange or unclear dream in primbon is often considered an 'empty dream' — ordinary sleep-noise, not a sign of anything. Not every dream needs interpreting." },
    takut: { id: "Rasa takut dalam mimpi menurut primbon sering jadi pertanda untuk lebih berhati-hati dalam waktu dekat — bukan soal mimpinya, tapi soal kewaspadaan yang perlu ditingkatkan.",
      en: "Fear in a dream, per primbon, often signals a need for more caution in the near future — not about the dream itself, but about raising your general alertness." },
    senang: { id: "Mimpi yang membawa rasa senang dalam primbon umumnya pertanda kabar baik akan datang, meski belum tentu bentuknya seperti di mimpi.",
      en: "A dream carrying happiness in primbon generally signals good news on the way, though it may not arrive in the same shape as it did in the dream." },
    sedih: { id: "Kesedihan dalam mimpi menurut primbon kadang dibaca terbalik — pertanda akan datangnya kelegaan setelah masa yang berat.",
      en: "Sadness in a dream, per primbon, is sometimes read in reverse — a sign that relief is coming after a hard stretch." },
    vivid: { id: "Mimpi yang terasa sangat nyata dalam primbon dianggap lebih layak diperhatikan daripada mimpi biasa — coba dicatat, siapa tahu maknanya baru jelas beberapa hari ke depan.",
      en: "A dream that feels unusually real, per primbon, is considered more worth noting than an ordinary one — write it down, its meaning may only become clear in the days ahead." },
  },
  islamic: {
    default: { en: "No specific symbol from the tradition matched this dream, but in the Ibn Sirin tradition, dreams without clear imagery are often classified as hadith an-nafs — the mind processing the day, not a message requiring interpretation. Not every dream carries meaning, and that's fine.",
      id: "Nggak ada simbol spesifik dari tradisi ini yang cocok, tapi dalam tradisi Ibn Sirin, mimpi tanpa gambaran jelas sering digolongkan sebagai hadith an-nafs — pikiran lagi ngolah harian, bukan pesan yang perlu ditafsir. Nggak semua mimpi punya makna, dan itu nggak masalah." },
    tenang: { en: "A calm dream without disturbance is generally read as a good sign, reflecting a settled state — a reassurance worth simply accepting.",
      id: "Mimpi tenang tanpa gangguan umumnya dibaca sebagai pertanda baik, nyerminin keadaan yang mapan — ketenangan yang bisa langsung diterima aja." },
    aneh: { en: "Dreams that feel confused or formless are often attributed to the mind's ordinary processing rather than to any deeper source — no interpretation needed.",
      id: "Mimpi yang kerasa bingung atau nggak berbentuk sering dianggap hasil dari pikiran yang lagi memproses hal biasa, bukan dari sumber yang lebih dalam — nggak perlu ditafsir." },
    takut: { en: "Fear in a dream without a clear cause is sometimes read as a prompt toward seeking protection and steadiness in waking life, more than a specific warning.",
      id: "Rasa takut di mimpi tanpa sebab jelas kadang dibaca sebagai dorongan buat nyari perlindungan dan ketenangan di kehidupan nyata, lebih dari sekadar peringatan spesifik." },
    senang: { en: "Unexplained joy in a dream is generally received as a good sign, though its form in waking life may look nothing like the dream itself.",
      id: "Kebahagiaan tanpa sebab jelas di mimpi umumnya diterima sebagai pertanda baik, meski bentuknya di kehidupan nyata bisa sama sekali beda dari yang di mimpi." },
    sedih: { en: "Sadness in a dream is sometimes read as preceding relief, following the pattern that hardship in a dream can foretell its opposite in waking life.",
      id: "Kesedihan di mimpi kadang dibaca sebagai pertanda kelegaan yang akan datang, mengikuti pola bahwa kesulitan di mimpi bisa jadi pertanda kebalikannya di dunia nyata." },
    vivid: { en: "A dream that feels unusually vivid is worth noting rather than dismissing, though the tradition still cautions against over-interpreting single dreams without a pattern.",
      id: "Mimpi yang terasa luar biasa nyata layak dicatat, bukan diabaikan, meski tradisi ini tetap mengingatkan untuk tidak berlebihan menafsirkan satu mimpi tanpa ada polanya." },
  },
};

export function genericReading(mood, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  const m = mood && GENERIC.jung[mood] ? mood : "default";
  return {
    jung: GENERIC.jung[m][l],
    primbon: GENERIC.primbon[m][l],
    islamic: GENERIC.islamic[m][l],
  };
}

// ---- Holistic synthesis for the offline path. Ties matched symbols
// into one connected reading instead of a list of separate lookups. ----

const THEME_LINE = {
  emotion: { id: "perasaan yang lagi naik ke permukaan, lebih cepat dari biasanya kamu olah", en: "feeling rising to the surface faster than you're used to processing it" },
  transformation: { id: "sesuatu di dalam dirimu lagi ganti bentuk, meski belum kelihatan dari luar", en: "something in you changing shape, even if it's not visible from outside yet" },
  anxiety: { id: "kekhawatiran yang belum sempat kamu ucapin ke diri sendiri secara sadar", en: "a worry you haven't consciously admitted to yourself yet" },
  ambition: { id: "dorongan buat naik level, entah itu status, posisi, atau pencapaian", en: "a pull toward rising — status, position, or achievement" },
  security: { id: "urusan soal rasa aman, entah itu rumah, keluarga, atau fondasi hidupmu", en: "something about safety — home, family, or the foundation of your life" },
  exposure: { id: "rasa takut ketahuan atau dinilai, dan diam-diam juga capek nyembunyiin sesuatu", en: "fear of being seen or judged, and quietly tired of hiding something" },
  fortune: { id: "pertanyaan soal cukup apa nggaknya kamu sekarang — secara materi maupun rasa dihargai", en: "a question about whether you have enough right now — materially or in feeling valued" },
  control: { id: "rasa nggak sepenuhnya pegang kendali atas arah hidupmu belakangan ini", en: "a sense of not fully holding the wheel of your own direction lately" },
  reflection: { id: "lagi ngaca ke diri sendiri, nyari bagian mana yang belum diakui sepenuhnya", en: "looking at yourself, searching for a part not yet fully acknowledged" },
  overwhelm: { id: "sesuatu yang lebih besar dari kapasitasmu buat nampung sekaligus", en: "something bigger than your current capacity to hold all at once" },
  union: { id: "penyatuan dua sisi yang tadinya kerasa terpisah dalam dirimu", en: "a merging of two sides of yourself that used to feel separate" },
  unfinished: { id: "urusan lama yang belum bener-bener selesai, meski udah lama nggak dibahas", en: "old business that isn't truly finished, even if it's been unspoken for a while" },
  loss: { id: "kekhawatiran kehilangan akses ke sesuatu yang kamu andalkan", en: "worry about losing access to something you rely on" },
  instinct: { id: "sisi naluriah yang belum sepenuhnya kamu percaya atau dengarkan", en: "an instinctual side you haven't fully trusted or listened to" },
  nourishment: { id: "pertanyaan soal apa kamu lagi cukup terisi, secara batin maupun fisik", en: "a question about whether you're being fed enough, emotionally or physically" },
  vitality: { id: "berapa banyak dari dirimu yang lagi terkuras buat orang atau hal lain", en: "how much of yourself is currently being spent on someone or something else" },
};

export function synthesizeOverall(hits, mood, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  if (!hits || hits.length === 0) {
    return l === "en"
      ? "No specific symbol anchored this dream, so read it by feeling rather than image — whatever mood you woke up with is probably the most honest summary of what it was processing."
      : "Nggak ada simbol spesifik yang jadi jangkar di mimpi ini, jadi bacanya lewat perasaan yang tersisa, bukan lewat gambar. Mood pas kamu bangun kemungkinan besar rangkuman paling jujur soal apa yang lagi diproses.";
  }

  const symbols = hits.map((h) => h.key);
  const themes = [...new Set(hits.map((h) => h.theme).filter(Boolean))];

  const sequence = l === "en"
    ? `This dream moves through ${symbols.join(", ")} in that order — worth noticing not just what showed up, but what came before what.`
    : `Mimpi ini bergerak lewat ${symbols.join(", ")} secara berurutan — yang penting bukan cuma apa yang muncul, tapi apa yang muncul duluan sebelum apa.`;

  const themeLines = themes.slice(0, 2).map((t) => (THEME_LINE[t] || {})[l]).filter(Boolean);
  const themeSentence = themeLines.length === 2
    ? (l === "en"
        ? `Underneath, it's holding two things at once: ${themeLines[0]}, and ${themeLines[1]}.`
        : `Di bawahnya, ada dua hal yang lagi dipegang bareng: ${themeLines[0]}, sama ${themeLines[1]}.`)
    : themeLines.length === 1
    ? (l === "en"
        ? `Underneath, the throughline is ${themeLines[0]}.`
        : `Di bawahnya, benang merahnya adalah ${themeLines[0]}.`)
    : "";

  const closing = l === "en"
    ? "Read the three lenses below as different angles on that same throughline, not three separate dreams."
    : "Baca tiga lensa di bawah sebagai sudut pandang beda dari benang merah yang sama, bukan tiga mimpi yang terpisah.";

  return [sequence, themeSentence, closing].filter(Boolean).join(" ");
}

// ---- Ties the dream's theme(s) to the dreamer's own known pattern
// (pancasuda from their weton) — only used when the dreamer is
// signed in and their profile is available. ----
const PANCASUDA_DREAM_NOTE = {
  Sri: { id: "watak dasarmu (Sri) biasanya bikin orang gampang percaya sama kamu — jadi kalau mimpi ini nyenggol soal dipercaya atau dikhianati, itu kemungkinan lebih berat buatmu daripada buat orang lain.",
    en: "your baseline temperament (Sri) usually makes people trust you easily — so if this dream touches on trust or betrayal, it likely lands heavier for you than it would for most people." },
  Lungguh: { id: "watak dasarmu (Lungguh) condong ke posisi dihormati — kalau mimpi ini ada unsur kehilangan kendali atau dipermalukan, itu kemungkinan nyentuh titik yang lebih sensitif dari biasanya.",
    en: "your baseline temperament (Lungguh) leans toward being respected — if this dream involves losing control or being embarrassed, it likely hits a more sensitive spot than usual." },
  Gedhong: { id: "watak dasarmu (Gedhong) condong nyimpen daripada nunjukin — kalau mimpi ini soal sesuatu yang kebongkar atau ketauan, itu kemungkinan mewakili ketakutan yang udah lama kamu pendam.",
    en: "your baseline temperament (Gedhong) leans toward holding things in rather than showing them — if this dream involves something being exposed or found out, it likely represents a fear you've been sitting on for a while." },
  Lara: { id: "watak dasarmu (Lara) emang lebih akrab sama gesekan dari biasanya orang — mimpi yang kerasa berat atau penuh konflik mungkin nggak seburuk yang kamu kira, itu emang pola normalmu buat ngolah sesuatu.",
    en: "your baseline temperament (Lara) is more used to friction than most — a dream that feels heavy or conflict-laden might not be as bad as it seems, it's genuinely just your normal way of processing things." },
  Pati: { id: "watak dasarmu (Pati) condong jadi yang nutup siklus — kalau mimpi ini ada unsur perpisahan atau akhir, itu kemungkinan bukan tanda buruk, tapi tandanya kamu emang lagi ngerjain peranmu.",
    en: "your baseline temperament (Pati) leans toward closing cycles — if this dream involves endings or separation, it's likely not a bad sign, just a sign you're doing the role you're built for." },
};

export function personalDreamNote(pancasudaKey, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  const note = PANCASUDA_DREAM_NOTE[pancasudaKey];
  if (!note) return "";
  return l === "en" ? `For you specifically: ${note[l]}` : `Khusus buat kamu: ${note[l]}`;
}

// ---- Recurring pattern across dream history. Real, computable
// personalization: counts how often each theme/symbol has shown up
// in the dreamer's past entries, not just this one dream. ----
export function findRecurringPattern(currentHits, pastDreamTexts, lang = "id") {
  const l = lang === "en" ? "en" : "id";
  if (!currentHits || currentHits.length === 0 || !pastDreamTexts || pastDreamTexts.length === 0) return "";

  const currentKeys = new Set(currentHits.map((h) => h.key));
  const currentThemes = new Set(currentHits.map((h) => h.theme));

  const keyCounts = {};
  const themeCounts = {};
  for (const text of pastDreamTexts) {
    const hits = matchSymbols(text);
    const seenKeys = new Set(), seenThemes = new Set();
    for (const h of hits) {
      if (currentKeys.has(h.key) && !seenKeys.has(h.key)) { keyCounts[h.key] = (keyCounts[h.key] || 0) + 1; seenKeys.add(h.key); }
      if (currentThemes.has(h.theme) && !seenThemes.has(h.theme)) { themeCounts[h.theme] = (themeCounts[h.theme] || 0) + 1; seenThemes.add(h.theme); }
    }
  }

  const repeatedKey = Object.entries(keyCounts).sort((a, b) => b[1] - a[1])[0];
  const repeatedTheme = Object.entries(themeCounts).sort((a, b) => b[1] - a[1])[0];

  if (repeatedKey && repeatedKey[1] >= 2) {
    const [key, count] = repeatedKey;
    return l === "en"
      ? `This isn't the first time — "${key}" has shown up in ${count} of your recent dreams too. A symbol that keeps returning usually means the thing it represents hasn't been resolved yet, not that you're missing something by not "getting" it sooner.`
      : `Ini bukan yang pertama — "${key}" udah muncul di ${count} mimpimu yang lain belakangan ini. Simbol yang terus balik biasanya artinya hal yang diwakilinya emang belum selesai, bukan berarti kamu kurang peka buat "nangkep" maknanya.`;
  }
  if (repeatedTheme && repeatedTheme[1] >= 2) {
    const [theme, count] = repeatedTheme;
    const line = (THEME_LINE[theme] || {})[l];
    if (line) {
      return l === "en"
        ? `Zooming out across your recent dreams, this same underlying theme keeps surfacing in different disguises: ${line}. Seeing it ${count + 1} times now is worth taking seriously.`
        : `Kalau dilihat dari mimpi-mimpimu belakangan ini, tema dasarnya sama, cuma nyamar beda-beda: ${line}. Muncul ${count + 1} kali sekarang, ini worth diseriusin.`;
    }
  }
  return "";
}

export function matchSymbols(text) {
  const t = text.toLowerCase();
  const hits = [];
  for (const [key, entry] of Object.entries(LEXICON)) {
    const found = entry.match.some((w) => {
      const escaped = w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      return new RegExp(`\\b${escaped}\\b`, "i").test(t);
    });
    if (found) hits.push({ key, ...entry });
  }
  return hits;
}
