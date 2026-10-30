import 'package:url_launcher/url_launcher.dart';
import 'bn.dart';

/// WhatsApp (wa.me) এর জন্যে নম্বর — শুধু অঙ্ক, দেশের কোডসহ।
///
/// wa.me লোকাল নম্বর (`017...`) চেনে না, আন্তর্জাতিক ফরম্যাট (`88017...`)
/// লাগে। আগে শুধু অঙ্ক রেখে পাঠানো হতো, তাই WhatsApp খুললেও "নম্বর সঠিক
/// নয়" দেখাত। বাংলা অঙ্কে লেখা নম্বরও (`০১৭...`) আগে পুরোটাই মুছে যেত।
String whatsAppNumber(String phone) {
  var digits = Bn.toAsciiDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 11 && digits.startsWith('01')) digits = '88$digits';
  return digits;
}

/// নির্দিষ্ট নম্বরে লেখা মেসেজসহ WhatsApp খোলে। খুলতে না পারলে `false`।
Future<bool> openWhatsApp(String phone, String message) {
  final number = whatsAppNumber(phone);
  if (number.isEmpty) return Future.value(false);
  return _launch(Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}'));
}

/// ফোনের ডায়ালার খোলে। খুলতে না পারলে `false`।
Future<bool> callPhone(String phone) {
  final number = Bn.toAsciiDigits(phone).replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) return Future.value(false);
  return _launch(Uri.parse('tel:$number'));
}

/// `canLaunchUrl` আগে না দেখে সরাসরি খোলার চেষ্টা।
///
/// Android 11+ এ manifest এ `<queries>` না থাকলে `canLaunchUrl` সবসময়
/// `false` দিত — WhatsApp ইনস্টল থাকলেও "খোলা যায়নি" দেখাত।
Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
