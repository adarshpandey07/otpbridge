import 'package:otpbridge/domain/models/models.dart';

/// How a brand was recognised — used by the classifier to weight confidence.
enum BrandMatchSource { sender, body }

/// A successful brand lookup: brand display name + resolved category.
class BrandMatch {
  const BrandMatch({
    required this.brand,
    required this.category,
    required this.source,
  });

  final String brand;
  final OtpCategory category;
  final BrandMatchSource source;
}

/// One curated brand: display name, default category, DLT sender codes and
/// body keywords. Bank entries get their category refined per-message
/// (login vs transaction vs UPI vs card).
class BrandEntry {
  const BrandEntry(
    this.name,
    this.category, {
    this.senderCodes = const [],
    this.keywords = const [],
    this.isBank = false,
  });

  final String name;
  final OtpCategory category;

  /// Uppercase sender-ID fragments matched against the normalised header
  /// (e.g. `VM-AMAZON-S` → `AMAZON`, `AX-HDFCBK` → `HDFCBK`).
  final List<String> senderCodes;

  /// Case-insensitive whole-word keywords matched against the body.
  final List<String> keywords;

  /// Banks/wallets whose category depends on the message content.
  final bool isBank;
}

/// Curated catalog of Indian (and global) brands with sender-ID patterns.
///
/// Indian commercial SMS headers follow the DLT format
/// `<route><operator>-<6-char sender ID>[-<suffix>]`, e.g. `VM-AMAZON`,
/// `AX-HDFCBK-S`, `JD-SBIINB`. [lookup] normalises the header and matches
/// the sender ID first (strongest signal), then falls back to body keywords.
class BrandCatalog {
  const BrandCatalog();

  /// Longest-first entry order matters for body-keyword matching
  /// ("Uber Eats" before "Uber", "Google Pay" before "Google").
  static final List<BrandEntry> entries = List.unmodifiable(<BrandEntry>[
    // ------------------------------------------------------- e-commerce
    const BrandEntry('Amazon', OtpCategory.ecommerce,
        senderCodes: ['AMAZON', 'AMZN'], keywords: ['amazon']),
    const BrandEntry('Flipkart', OtpCategory.ecommerce,
        senderCodes: ['FLPKRT', 'FKRTOD', 'FLIPKT'], keywords: ['flipkart']),
    const BrandEntry('Myntra', OtpCategory.ecommerce,
        senderCodes: ['MYNTRA'], keywords: ['myntra']),
    const BrandEntry('Ajio', OtpCategory.ecommerce,
        senderCodes: ['AJIOSM', 'AJIOFS'], keywords: ['ajio']),
    const BrandEntry('Meesho', OtpCategory.ecommerce,
        senderCodes: ['MEESHO'], keywords: ['meesho']),
    const BrandEntry('Nykaa', OtpCategory.ecommerce,
        senderCodes: ['NYKAAA', 'NYKAAF'], keywords: ['nykaa']),
    const BrandEntry('Snapdeal', OtpCategory.ecommerce,
        senderCodes: ['SNPDEL', 'SNAPDL'], keywords: ['snapdeal']),
    const BrandEntry('Tata CLiQ', OtpCategory.ecommerce,
        senderCodes: ['TATACL', 'TATCLQ'], keywords: ['tata cliq', 'tatacliq']),

    // ---------------------------------------------------- food delivery
    const BrandEntry('Uber Eats', OtpCategory.foodDelivery,
        senderCodes: ['UBREAT'], keywords: ['uber eats', 'ubereats']),
    const BrandEntry('Swiggy', OtpCategory.foodDelivery,
        senderCodes: ['SWIGGY', 'SWGGYS'], keywords: ['swiggy']),
    const BrandEntry('Zomato', OtpCategory.foodDelivery,
        senderCodes: ['ZOMATO', 'ZOMATOF'], keywords: ['zomato']),
    const BrandEntry("Domino's", OtpCategory.foodDelivery,
        senderCodes: ['DOMINO', 'DMNOSP'],
        keywords: ['dominos', "domino's"]),
    const BrandEntry('KFC', OtpCategory.foodDelivery,
        senderCodes: ['KFCIND'], keywords: ['kfc']),
    const BrandEntry('Pizza Hut', OtpCategory.foodDelivery,
        senderCodes: ['PIZZAH', 'PZAHUT'], keywords: ['pizza hut']),
    const BrandEntry('EatSure', OtpCategory.foodDelivery,
        senderCodes: ['EATSUR'], keywords: ['eatsure', 'faasos']),

    // ---------------------------------------------------------- grocery
    const BrandEntry('BigBasket', OtpCategory.grocery,
        senderCodes: ['BIGBKT', 'BGBSKT', 'BIGBASKET'],
        keywords: ['bigbasket', 'big basket']),
    const BrandEntry('Blinkit', OtpCategory.grocery,
        senderCodes: ['BLNKIT', 'BLINKIT', 'GROFRS'],
        keywords: ['blinkit', 'grofers']),
    const BrandEntry('Zepto', OtpCategory.grocery,
        senderCodes: ['ZEPTON', 'ZEPTOO'], keywords: ['zepto']),
    const BrandEntry('JioMart', OtpCategory.grocery,
        senderCodes: ['JIOMRT', 'JIOMART'], keywords: ['jiomart']),
    const BrandEntry('DMart', OtpCategory.grocery,
        senderCodes: ['DMARTS', 'DMARTR'], keywords: ['dmart', 'd-mart']),
    const BrandEntry('Swiggy Instamart', OtpCategory.grocery,
        senderCodes: ['INSTMT'], keywords: ['instamart']),

    // ------------------------------------------------------- investments
    // NOTE: broker/AMC arms must precede their parent banks/wallets so body
    // keywords like "HDFC Securities" or "Paytm Money" resolve before the
    // bare "HDFC"/"Paytm" entries below.
    const BrandEntry('Zerodha Coin', OtpCategory.investment,
        senderCodes: ['COINZR'],
        keywords: ['zerodha coin', 'coin by zerodha']),
    const BrandEntry('Zerodha', OtpCategory.investment,
        senderCodes: ['ZERODH', 'ZRODHA'], keywords: ['zerodha']),
    const BrandEntry('Groww', OtpCategory.investment,
        senderCodes: ['GROWWW', 'GROWWI'], keywords: ['groww']),
    const BrandEntry('Upstox', OtpCategory.investment,
        senderCodes: ['UPSTOX', 'UPSTKX'], keywords: ['upstox']),
    const BrandEntry('Angel One', OtpCategory.investment,
        senderCodes: ['ANGELO', 'ANGLBK'],
        keywords: ['angel one', 'angel broking']),
    const BrandEntry('Kuvera', OtpCategory.investment,
        senderCodes: ['KUVERA'], keywords: ['kuvera']),
    const BrandEntry('Paytm Money', OtpCategory.investment,
        senderCodes: ['PYTMMN', 'PTMMNY'], keywords: ['paytm money']),
    const BrandEntry('ICICI Direct', OtpCategory.investment,
        senderCodes: ['ICIDIR', 'IDIRCT'],
        keywords: ['icici direct', 'icicidirect']),
    const BrandEntry('HDFC Securities', OtpCategory.investment,
        senderCodes: ['HDFCSE', 'HDFCSC'],
        keywords: ['hdfc securities', 'hdfc sec']),
    const BrandEntry('Kotak Securities', OtpCategory.investment,
        senderCodes: ['KOTSEC', 'KTKSEC'], keywords: ['kotak securities']),
    const BrandEntry('5paisa', OtpCategory.investment,
        senderCodes: ['5PAISA', 'PAISAF'], keywords: ['5paisa']),
    const BrandEntry('Dhan', OtpCategory.investment,
        senderCodes: ['DHANHQ'], keywords: ['dhan']),
    const BrandEntry('INDmoney', OtpCategory.investment,
        senderCodes: ['INDMNY'], keywords: ['indmoney', 'ind money']),
    const BrandEntry('ET Money', OtpCategory.investment,
        senderCodes: ['ETMONY'], keywords: ['et money', 'etmoney']),
    const BrandEntry('Smallcase', OtpCategory.investment,
        senderCodes: ['SMLCSE'], keywords: ['smallcase']),

    // --------------------------------------------------------- insurance
    // NOTE: insurers must precede their parent banks ("SBI Life" before
    // "SBI", "HDFC Life" before "HDFC").
    const BrandEntry('LIC', OtpCategory.insurance,
        senderCodes: ['LICIND', 'LICSMS'], keywords: ['lic']),
    const BrandEntry('HDFC Life', OtpCategory.insurance,
        senderCodes: ['HDFCLF', 'HDFCLI'], keywords: ['hdfc life']),
    const BrandEntry('ICICI Prudential', OtpCategory.insurance,
        senderCodes: ['ICIPRU', 'IPRULI'],
        keywords: ['icici prudential', 'icici pru']),
    const BrandEntry('SBI Life', OtpCategory.insurance,
        senderCodes: ['SBILIF'], keywords: ['sbi life']),
    const BrandEntry('Max Life', OtpCategory.insurance,
        senderCodes: ['MAXLIF'], keywords: ['max life']),
    const BrandEntry('Bajaj Allianz', OtpCategory.insurance,
        senderCodes: ['BAJAJA', 'BAJALZ'], keywords: ['bajaj allianz']),
    const BrandEntry('Star Health', OtpCategory.insurance,
        senderCodes: ['STARHL', 'STRHLT'], keywords: ['star health']),
    const BrandEntry('Niva Bupa', OtpCategory.insurance,
        senderCodes: ['NIVBUP', 'MAXBUP'],
        keywords: ['niva bupa', 'max bupa']),
    const BrandEntry('Acko', OtpCategory.insurance,
        senderCodes: ['ACKOGI', 'ACKOIN'], keywords: ['acko']),
    const BrandEntry('Digit Insurance', OtpCategory.insurance,
        senderCodes: ['GODIGT', 'DIGITG'],
        keywords: ['godigit', 'go digit', 'digit insurance']),
    const BrandEntry('PolicyBazaar', OtpCategory.insurance,
        senderCodes: ['PLCYBZ', 'PBAZAR'],
        keywords: ['policybazaar', 'policy bazaar']),
    const BrandEntry('Tata AIG', OtpCategory.insurance,
        senderCodes: ['TATAIG'], keywords: ['tata aig']),
    const BrandEntry('New India Assurance', OtpCategory.insurance,
        senderCodes: ['NIACLI', 'NIAINS'], keywords: ['new india assurance']),

    // ---------------------------------------------------------- banking
    const BrandEntry('SBI', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: [
          'SBIINB', 'SBIOTP', 'SBIPSG', 'SBIBNK', 'SBICRD', 'SBIUPI',
          'SBIATM', 'CBSSBI', 'SBIYON',
        ],
        keywords: ['sbi', 'state bank']),
    const BrandEntry('HDFC Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['HDFCBK', 'HDFCBN', 'HDFCB'],
        keywords: ['hdfc']),
    const BrandEntry('ICICI Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['ICICIB', 'ICICIT', 'ICICIC'],
        keywords: ['icici']),
    const BrandEntry('Axis Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['AXISBK', 'AXISB'],
        keywords: ['axis bank', 'axisbank']),
    const BrandEntry('Kotak Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['KOTAKB', 'KOTAKM', 'KOTKMB'],
        keywords: ['kotak']),
    const BrandEntry('PNB', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['PNBSMS', 'PNBOTP'],
        keywords: ['pnb', 'punjab national bank']),
    const BrandEntry('Bank of Baroda', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['BOBTXN', 'BOBSMS'],
        keywords: ['bank of baroda', 'bobcard']),
    const BrandEntry('Canara Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['CANBNK', 'CANARA'],
        keywords: ['canara']),
    const BrandEntry('Union Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['UNIONB', 'UBOI'],
        keywords: ['union bank']),
    const BrandEntry('IDFC FIRST Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['IDFCFB', 'IDFCBK'],
        keywords: ['idfc']),
    const BrandEntry('Yes Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['YESBNK', 'YESBK'],
        keywords: ['yes bank', 'yesbank']),
    const BrandEntry('IndusInd Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['INDUSB', 'INDBNK'],
        keywords: ['indusind']),
    const BrandEntry('Federal Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['FEDBNK', 'FEDERL'],
        keywords: ['federal bank']),
    const BrandEntry('RBL Bank', OtpCategory.bankingLogin,
        isBank: true,
        senderCodes: ['RBLBNK', 'RBLBK'],
        keywords: ['rbl bank', 'rblbank']),

    // -------------------------------------------------------------- upi
    const BrandEntry('Paytm', OtpCategory.upi,
        isBank: true,
        senderCodes: ['PAYTMB', 'IPAYTM', 'PAYTM', 'PYTMPB'],
        keywords: ['paytm']),
    const BrandEntry('PhonePe', OtpCategory.upi,
        isBank: true,
        senderCodes: ['PHONPE', 'PHNEPE'],
        keywords: ['phonepe', 'phone pe']),
    const BrandEntry('Google Pay', OtpCategory.upi,
        isBank: true,
        senderCodes: ['GPAYIN', 'GOOGLP'],
        keywords: ['google pay', 'gpay']),
    const BrandEntry('BHIM', OtpCategory.upi,
        isBank: true,
        senderCodes: ['BHIMPY', 'NPCIBH'],
        keywords: ['bhim']),
    const BrandEntry('CRED', OtpCategory.creditCard,
        senderCodes: ['CREDCL', 'CREDPY'], keywords: ['cred']),
    const BrandEntry('MobiKwik', OtpCategory.upi,
        isBank: true,
        senderCodes: ['MBKWIK', 'MOBKWK'],
        keywords: ['mobikwik']),
    const BrandEntry('Freecharge', OtpCategory.upi,
        isBank: true,
        senderCodes: ['FRECHG', 'FCHRGE'],
        keywords: ['freecharge']),

    // ------------------------------------------------------ ride booking
    const BrandEntry('Uber', OtpCategory.rideBooking,
        senderCodes: ['UBERIN', 'UBER'], keywords: ['uber']),
    const BrandEntry('Ola', OtpCategory.rideBooking,
        senderCodes: ['OLACAB', 'OLAMNY'],
        keywords: ['ola cabs', 'olacabs', 'ola']),
    const BrandEntry('Rapido', OtpCategory.rideBooking,
        senderCodes: ['RAPIDO'], keywords: ['rapido']),
    const BrandEntry('BluSmart', OtpCategory.rideBooking,
        senderCodes: ['BLUSMT'], keywords: ['blusmart']),

    // ------------------------------------------------------------ travel
    const BrandEntry('MakeMyTrip', OtpCategory.travel,
        senderCodes: ['MKMYTP', 'MMTRIP'],
        keywords: ['makemytrip', 'make my trip']),
    const BrandEntry('IRCTC', OtpCategory.travel,
        senderCodes: ['IRCTCI', 'IRCTC'], keywords: ['irctc']),
    const BrandEntry('Ixigo', OtpCategory.travel,
        senderCodes: ['IXIGOO', 'IXIGO'], keywords: ['ixigo']),
    const BrandEntry('Goibibo', OtpCategory.travel,
        senderCodes: ['GOIBIB'], keywords: ['goibibo']),
    const BrandEntry('Cleartrip', OtpCategory.travel,
        senderCodes: ['CLRTRP'], keywords: ['cleartrip']),
    const BrandEntry('redBus', OtpCategory.travel,
        senderCodes: ['REDBUS'], keywords: ['redbus']),
    const BrandEntry('Yatra', OtpCategory.travel,
        senderCodes: ['YATRAA'], keywords: ['yatra']),
    const BrandEntry('EaseMyTrip', OtpCategory.travel,
        senderCodes: ['EZYTRP', 'EMTRIP'], keywords: ['easemytrip']),
    const BrandEntry('IndiGo', OtpCategory.travel,
        senderCodes: ['INDIGO', 'GOINDG'], keywords: ['indigo', '6e']),
    const BrandEntry('Air India', OtpCategory.travel,
        senderCodes: ['AIRIND'], keywords: ['air india']),
    const BrandEntry('SpiceJet', OtpCategory.travel,
        senderCodes: ['SPCJET'], keywords: ['spicejet']),

    // ------------------------------------------------------------- hotel
    const BrandEntry('OYO', OtpCategory.hotel,
        senderCodes: ['OYOROM', 'OYORMS'], keywords: ['oyo']),
    const BrandEntry('FabHotels', OtpCategory.hotel,
        senderCodes: ['FABHTL'], keywords: ['fabhotels']),
    const BrandEntry('Treebo', OtpCategory.hotel,
        senderCodes: ['TREEBO'], keywords: ['treebo']),

    // ----------------------------------------------------------- telecom
    const BrandEntry('Airtel', OtpCategory.telecom,
        senderCodes: ['AIRTEL', 'ARTLBB'], keywords: ['airtel']),
    const BrandEntry('Jio', OtpCategory.telecom,
        senderCodes: ['JIONET', 'JIOINF', 'RJIONO'],
        keywords: ['jio']),
    const BrandEntry('Vi', OtpCategory.telecom,
        senderCodes: ['VICARE', 'VODAID', 'IDEAVI'],
        keywords: ['vodafone', 'vi care']),
    const BrandEntry('BSNL', OtpCategory.telecom,
        senderCodes: ['BSNLIN'], keywords: ['bsnl']),

    // ---------------------------------------------------- recharge / DTH
    // Prepaid recharges from Airtel/Jio/Vi arrive under the telecom senders
    // above and are refined per-message by [refineTelecomCategory]; the
    // entries here are pure-play DTH operators.
    const BrandEntry('Tata Play', OtpCategory.recharge,
        senderCodes: ['TATAPL', 'TATSKY'],
        keywords: ['tata play', 'tata sky']),
    const BrandEntry('Dish TV', OtpCategory.recharge,
        senderCodes: ['DISHTV'], keywords: ['dish tv', 'dishtv']),
    const BrandEntry('Airtel DTH', OtpCategory.recharge,
        senderCodes: ['ARTLTV'],
        keywords: ['airtel dth', 'airtel digital tv']),
    const BrandEntry('d2h', OtpCategory.recharge,
        senderCodes: ['D2HTVS', 'VDDTOH'], keywords: ['d2h']),

    // ----------------------------------------------------- entertainment
    const BrandEntry('Netflix', OtpCategory.entertainment,
        senderCodes: ['NETFLX'], keywords: ['netflix']),
    const BrandEntry('Disney+ Hotstar', OtpCategory.entertainment,
        senderCodes: ['HOTSTR', 'HTSTAR'],
        keywords: ['hotstar', 'jiohotstar']),
    const BrandEntry('Spotify', OtpCategory.entertainment,
        senderCodes: ['SPOTFY'], keywords: ['spotify']),
    const BrandEntry('SonyLIV', OtpCategory.entertainment,
        senderCodes: ['SONYLV'], keywords: ['sonyliv']),
    const BrandEntry('ZEE5', OtpCategory.entertainment,
        senderCodes: ['ZEE5IN'], keywords: ['zee5']),
    const BrandEntry('BookMyShow', OtpCategory.entertainment,
        senderCodes: ['BKMYSH', 'BMSHOW'],
        keywords: ['bookmyshow', 'book my show']),

    // ------------------------------------------------ login/registration
    const BrandEntry('WhatsApp', OtpCategory.login,
        senderCodes: ['WHTSAP', 'WATSAP', 'WHATSA'],
        keywords: ['whatsapp']),
    const BrandEntry('Instagram', OtpCategory.login,
        senderCodes: ['INSTGR', 'INSTAG'], keywords: ['instagram']),
    const BrandEntry('Facebook', OtpCategory.login,
        senderCodes: ['FCBOOK', 'FACEBK'], keywords: ['facebook']),
    const BrandEntry('Telegram', OtpCategory.login,
        senderCodes: ['TELEGM', 'TLGRAM'], keywords: ['telegram']),
    const BrandEntry('Microsoft', OtpCategory.login,
        senderCodes: ['MSFTIN', 'MCRSFT'], keywords: ['microsoft']),
    const BrandEntry('LinkedIn', OtpCategory.login,
        senderCodes: ['LNKDIN', 'LINKED'], keywords: ['linkedin']),
    const BrandEntry('Google', OtpCategory.login,
        senderCodes: ['GOOGLE', 'GOOGL'], keywords: ['google']),
    const BrandEntry('Apple', OtpCategory.login,
        senderCodes: ['APPLEI'], keywords: ['apple id', 'icloud']),
    const BrandEntry('X (Twitter)', OtpCategory.login,
        senderCodes: ['TWITTR'], keywords: ['twitter']),
    const BrandEntry('Snapchat', OtpCategory.login,
        senderCodes: ['SNPCHT'], keywords: ['snapchat']),

    // ----------------------------------------------------------- courier
    const BrandEntry('DTDC', OtpCategory.courier,
        senderCodes: ['DTDCIN', 'DTDCCR'], keywords: ['dtdc']),
    const BrandEntry('Delhivery', OtpCategory.courier,
        senderCodes: ['DLHVRY', 'DELHIV'], keywords: ['delhivery']),
    const BrandEntry('Blue Dart', OtpCategory.courier,
        senderCodes: ['BLDART', 'BLUDRT'],
        keywords: ['bluedart', 'blue dart']),
    const BrandEntry('Ekart', OtpCategory.courier,
        senderCodes: ['EKARTL', 'EKARTS'], keywords: ['ekart']),
    const BrandEntry('India Post', OtpCategory.courier,
        senderCodes: ['INDPST', 'IPOSTS'],
        keywords: ['india post', 'speed post']),
    const BrandEntry('DHL', OtpCategory.courier,
        senderCodes: ['DHLEXP'], keywords: ['dhl']),
    const BrandEntry('FedEx', OtpCategory.courier,
        senderCodes: ['FEDEXP'], keywords: ['fedex']),
    const BrandEntry('XpressBees', OtpCategory.courier,
        senderCodes: ['XPRBEE', 'XBEES'], keywords: ['xpressbees']),
    const BrandEntry('Shadowfax', OtpCategory.courier,
        senderCodes: ['SHDFAX'], keywords: ['shadowfax']),

    // --------------------------------------------------------- utilities
    const BrandEntry('Tata Power', OtpCategory.utilityBills,
        senderCodes: ['TATAPW', 'TPWROD'], keywords: ['tata power']),
    const BrandEntry('Adani Electricity', OtpCategory.utilityBills,
        senderCodes: ['ADANIE', 'ADNIEL'],
        keywords: ['adani electricity']),
    const BrandEntry('BSES', OtpCategory.utilityBills,
        senderCodes: ['BSESRP', 'BSESYP'], keywords: ['bses']),
    const BrandEntry('MSEDCL', OtpCategory.utilityBills,
        senderCodes: ['MSEDCL', 'MAHADS'],
        keywords: ['msedcl', 'mahadiscom', 'mahavitaran']),
    const BrandEntry('Torrent Power', OtpCategory.utilityBills,
        senderCodes: ['TORPWR'], keywords: ['torrent power']),
    const BrandEntry('Indane Gas', OtpCategory.utilityBills,
        senderCodes: ['INDANE', 'IOCLGS'],
        keywords: ['indane', 'indianoil', 'indian oil']),
    const BrandEntry('HP Gas', OtpCategory.utilityBills,
        senderCodes: ['HPGASS', 'HPCLGS'], keywords: ['hp gas']),
    const BrandEntry('Bharat Gas', OtpCategory.utilityBills,
        senderCodes: ['BHRTGS', 'BPCLGS'], keywords: ['bharat gas', 'bharatgas']),
    const BrandEntry('IGL', OtpCategory.utilityBills,
        senderCodes: ['IGLGAS'], keywords: ['indraprastha gas']),
    const BrandEntry('Mahanagar Gas', OtpCategory.utilityBills,
        senderCodes: ['MGLGAS'], keywords: ['mahanagar gas']),

    // -------------------------------------------------------- government
    const BrandEntry('UIDAI / Aadhaar', OtpCategory.government,
        senderCodes: ['UIDAII', 'AADHAR', 'UIDAI'],
        keywords: ['uidai', 'aadhaar', 'aadhar']),
    const BrandEntry('Income Tax Dept', OtpCategory.tax,
        senderCodes: ['ITDEPT', 'ITDEFL', 'INCTAX'],
        keywords: ['income tax', 'e-filing', 'itr']),
    const BrandEntry('DigiLocker', OtpCategory.government,
        senderCodes: ['DIGLKR', 'DGLOCK'], keywords: ['digilocker']),
    const BrandEntry('CoWIN', OtpCategory.government,
        senderCodes: ['COWINI', 'NHPSMS'], keywords: ['cowin', 'co-win']),
    const BrandEntry('EPFO', OtpCategory.government,
        senderCodes: ['EPFOHO', 'EPFOIN'], keywords: ['epfo']),
    const BrandEntry('UMANG', OtpCategory.government,
        senderCodes: ['UMANGA'], keywords: ['umang']),
    const BrandEntry('Passport Seva', OtpCategory.government,
        senderCodes: ['PSPRTS', 'PSKSEV'], keywords: ['passport seva']),

    // --------------------------------------------------------------- tax
    const BrandEntry('GSTN', OtpCategory.tax,
        senderCodes: ['GSTNIN', 'GSTSYS'],
        keywords: ['gstn', 'gstin', 'gst portal']),
    const BrandEntry('TRACES', OtpCategory.tax,
        senderCodes: ['TRACES', 'TDSCPC'], keywords: ['traces', 'tdscpc']),
    const BrandEntry('TIN-NSDL', OtpCategory.tax,
        senderCodes: ['NSDLTN', 'NSDLPN'],
        keywords: ['tin-nsdl', 'tin nsdl', 'nsdl']),
    const BrandEntry('Protean', OtpCategory.tax,
        senderCodes: ['PROTEA', 'PRTNEG'], keywords: ['protean']),

    // -------------------------------------------------------- healthcare
    const BrandEntry('Practo', OtpCategory.healthcare,
        senderCodes: ['PRACTO'], keywords: ['practo']),
    const BrandEntry('PharmEasy', OtpCategory.healthcare,
        senderCodes: ['PHRMEZ', 'PHEASY'], keywords: ['pharmeasy']),
    const BrandEntry('Tata 1mg', OtpCategory.healthcare,
        senderCodes: ['ONEMGS', 'TATMG'], keywords: ['1mg']),
    const BrandEntry('Netmeds', OtpCategory.healthcare,
        senderCodes: ['NETMDS'], keywords: ['netmeds']),
    const BrandEntry('Apollo', OtpCategory.healthcare,
        senderCodes: ['APOLLO', 'APLO24'],
        keywords: ['apollo 247', 'apollo pharmacy']),
  ]);

  /// Bank-category refinement — shared with the classifier.
  ///
  /// Order matters: explicit card > UPI > transaction verbs > login verbs.
  static OtpCategory refineBankCategory(String body, OtpCategory fallback) {
    final b = body.toLowerCase();
    bool has(String pattern) => RegExp(pattern).hasMatch(b);

    if (has(r'\bcredit\s*card\b')) return OtpCategory.creditCard;
    if (has(r'\bdebit\s*card\b')) return OtpCategory.debitCard;
    if (has(r'\bupi\b|\bvpa\b|\bcollect\s+request\b')) return OtpCategory.upi;
    if (has(r'\bcredited\b|\bdebited\b|\btransfer(?:red)?\b|\bspent\b|'
        r'\btxn\b|\btransaction\b|\bwithdraw(?:al|n)?\b|\bimps\b|\bneft\b|'
        r'\brtgs\b|\bpurchase\b')) {
      return OtpCategory.bankingTransaction;
    }
    if (has(r'\blog\s*[io]n\b|\blogin\b|\blogon\b|\bnet\s*banking\b|'
        r'\binternet\s+banking\b|\bsign\s*in\b')) {
      return OtpCategory.bankingLogin;
    }
    return fallback;
  }

  /// Telecom-category refinement — shared with the classifier.
  ///
  /// Prepaid/DTH recharge confirmations ("Recharge of Rs 239 successful.
  /// Validity 28 days") become [OtpCategory.recharge]; logins/OTPs for the
  /// telecom account itself stay [OtpCategory.telecom].
  static OtpCategory refineTelecomCategory(String body, OtpCategory fallback) {
    final b = body.toLowerCase();
    bool has(String pattern) => RegExp(pattern).hasMatch(b);

    // Account access (login/verification) is about the telecom account,
    // not about a recharge — even when a plan happens to be mentioned.
    if (has(r'\blog\s*[io]n\b|\bsign\s*in\b|\bpassword\b|'
        r'\bverification\s+code\b|\bverify\s+your\b')) {
      return fallback;
    }
    if (has(r'\brecharge\b|\bplan\s+activat\w*\b|\bvalidity\b|'
        r'\bdata\s+pack\b|\btalk\s*time\b|\btop[\s-]?up\b|\bdth\b')) {
      return OtpCategory.recharge;
    }
    return fallback;
  }

  /// Resolve an entry's category for a specific message body: banks get the
  /// card/UPI/transaction/login refinement, telecom brands get the
  /// recharge-vs-account refinement.
  static OtpCategory _categoryFor(BrandEntry entry, String body) {
    final category = entry.isBank
        ? refineBankCategory(body, entry.category)
        : entry.category;
    return category == OtpCategory.telecom
        ? refineTelecomCategory(body, category)
        : category;
  }

  /// Look up a brand for the given [sender] header and [body].
  ///
  /// Sender-ID matches win over body-keyword matches. Returns null when no
  /// curated brand applies.
  BrandMatch? lookup({required String sender, required String body}) {
    final core = normalizeSender(sender);

    if (core.isNotEmpty) {
      for (final entry in entries) {
        for (final code in entry.senderCodes) {
          if (core == code || core.contains(code)) {
            return BrandMatch(
              brand: entry.name,
              category: _categoryFor(entry, body),
              source: BrandMatchSource.sender,
            );
          }
        }
      }
    }

    for (final entry in entries) {
      for (final keyword in entry.keywords) {
        final pattern = RegExp(
          '\\b${RegExp.escape(keyword)}\\b',
          caseSensitive: false,
        );
        if (pattern.hasMatch(body)) {
          return BrandMatch(
            brand: entry.name,
            category: _categoryFor(entry, body),
            source: BrandMatchSource.body,
          );
        }
      }
    }

    return null;
  }

  /// Normalise an Indian DLT header to its sender-ID core:
  /// `VM-AMAZON-S` → `AMAZON`, `AX-HDFCBK` → `HDFCBK`, `Amazon` → `AMAZON`.
  /// Pure phone numbers normalise to '' (no header to match).
  static String normalizeSender(String sender) {
    var s = sender.trim().toUpperCase();
    if (s.isEmpty) return '';
    // Phone numbers carry no brand information.
    if (RegExp(r'^\+?[\d\s-]{7,}$').hasMatch(s)) return '';
    // Strip 2-char route/operator prefix (VM-, AX-, JD-, TX-, VK-, BP-…)
    // and 1-2 char DLT suffix (-S, -P, -T, -G).
    s = s.replaceFirst(RegExp(r'^[A-Z]{2}-'), '');
    s = s.replaceFirst(RegExp(r'-[A-Z]{1,2}$'), '');
    // Drop any remaining separators.
    return s.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
