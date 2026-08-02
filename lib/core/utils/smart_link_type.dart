/// Every kind of link EduSphere's Smart Links Engine knows how to detect
/// and open. Backend-configured values (contact items, payment methods,
/// branding social links, etc.) declare a raw string; this is purely a
/// client-side classification of *how* to open that string.
enum SmartLinkType {
  phone,
  whatsapp,
  email,
  sms,
  facebook,
  instagram,
  youtube,
  tiktok,
  twitter, // X
  linkedin,
  telegram,
  googleMaps,
  website,
  unknown,
}
