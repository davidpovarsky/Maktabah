import SwiftUI

// MARK: - Localization

private enum Lang {
    static var code: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    static func pick(ar: String, id: String, en: String) -> String {
        switch code {
        case "ar": return ar
        case "id": return id
        default: return en
        }
    }
}

// MARK: - Feature Data

private struct FeatureItem {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    var badge: String? = nil
}

private func makeFeatures() -> [FeatureItem] {
    #if os(iOS)
    return [
        FeatureItem(
            iconName: "books.vertical.fill",
            iconColor: .blue,
            title: Lang.pick(
                ar: "تبويبات متعددة على الآيفون",
                id: "Multi-Tab di iPhone",
                en: "Multi-Tab on iPhone"
            ),
            description: Lang.pick(
                ar: "افتح أكثر من كتاب وانتقل بين القراءات بسهولة أكبر.",
                id: "Buka beberapa buku dan pindah antar bacaan dengan lebih mudah.",
                en: "Open multiple books and switch between readings more easily."
            ),
            badge: Lang.pick(
                ar: "جديد",
                id: "Baru",
                en: "New"
            )
        ),
        FeatureItem(
            iconName: "paintpalette.fill",
            iconColor: .brown,
            title: Lang.pick(
                ar: "مظهر سيبيا جديد",
                id: "Tema Sepia Baru",
                en: "New Sepia Theme"
            ),
            description: Lang.pick(
                ar: "مظهر مخصص أكثر هدوءاً وراحة للقراءة الطويلة.",
                id: "Tema custom yang lebih tenang dan nyaman untuk membaca lama.",
                en: "A calmer custom theme designed for longer reading sessions."
            )
        ),
        FeatureItem(
            iconName: "textformat",
            iconColor: .purple,
            title: Lang.pick(
                ar: "خطوط قارئ مخصصة",
                id: "Font Kustom Reader",
                en: "Custom Reader Fonts"
            ),
            description: Lang.pick(
                ar: "استورد خطوطك الخاصة واخترها مباشرة من إعدادات القراءة.",
                id: "Impor font sendiri dan pakai langsung dari pengaturan reader.",
                en: "Import your own fonts and use them directly from reader settings."
            )
        ),
        FeatureItem(
            iconName: "text.magnifyingglass",
            iconColor: .green,
            title: Lang.pick(
                ar: "بحث عربي أدق",
                id: "Pencarian Arab Lebih Akurat",
                en: "Better Arabic Search"
            ),
            description: Lang.pick(
                ar: "تحسين البحث في أسماء الكتب والرواة مع فلترة النتائج حسب الكتاب.",
                id: "Pencarian kitab dan perawi ditingkatkan, termasuk filter hasil berdasarkan buku.",
                en: "Improved book and narrator search, including filtering results by book."
            )
        ),
        FeatureItem(
            iconName: "arrow.triangle.2.circlepath.icloud.fill",
            iconColor: .orange,
            title: Lang.pick(
                ar: "مزامنة أكثر ثباتاً",
                id: "Sinkronisasi Lebih Stabil",
                en: "More Stable Sync"
            ),
            description: Lang.pick(
                ar: "تحسين مزامنة CloudKit للسجل والمفضلة والملاحظات ونتائج البحث المحفوظة.",
                id: "CloudKit diperkuat untuk riwayat, favorit, catatan, dan hasil pencarian tersimpan.",
                en: "CloudKit sync is stronger for history, favorites, annotations, and saved search results."
            )
        ),
    ]
    #else
    return [
        FeatureItem(
            iconName: "clock.fill",
            iconColor: .blue,
            title: Lang.pick(
                ar: "المفضلة والسجل",
                id: "Favorit & Riwayat",
                en: "Favorites & History"
            ),
            description: Lang.pick(
                ar: "أصبحت الكتب المفضلة وسجل القراءة متاحة على Mac، وتتم مزامنتها بين iPhone وiPad وMac.",
                id: "Kitab favorit dan riwayat bacaan kini tersedia di Mac. Semua disinkronkan antar perangkat iPhone, iPad, dan Mac.",
                en: "Favorite books and reading history are now available on Mac and sync across iPhone, iPad, and Mac."
            ),
            badge: Lang.pick(
                ar: "جديد",
                id: "Baru",
                en: "New"
            )
        ),
        FeatureItem(
            iconName: "square.and.arrow.down.on.square.fill",
            iconColor: .green,
            title: Lang.pick(
                ar: "ترحيل استيراد الكتب",
                id: "Migrasi Impor Kitab",
                en: "Book Import Migration"
            ),
            description: Lang.pick(
                ar: "تحسين ترحيل معرفات الكتب عند الاستيراد حتى تبقى الملاحظات ونتائج البحث مرتبطة بالكتاب الصحيح.",
                id: "Migrasi ID kitab saat impor diperbaiki agar catatan dan hasil pencarian tetap tersambung ke kitab yang benar.",
                en: "Book ID migration during import has been improved so annotations and saved search results stay linked to the right book."
            )
        ),
        FeatureItem(
            iconName: "accessibility",
            iconColor: .orange,
            title: Lang.pick(
                ar: "تحسين إمكانية الوصول",
                id: "Aksesibilitas Diperluas",
                en: "Expanded Accessibility"
            ),
            description: Lang.pick(
                ar: "إضافة ميزات إمكانية الوصول والتلميحات في عدة أجزاء من التطبيق.",
                id: "Fitur aksesibilitas dan tooltip ditambahkan di beberapa bagian aplikasi.",
                en: "Accessibility features and tooltips have been added in several parts of the app."
            )
        ),
        FeatureItem(
            iconName: "arrow.triangle.2.circlepath.icloud.fill",
            iconColor: .purple,
            title: Lang.pick(
                ar: "مزامنة CloudKit",
                id: "Sinkronisasi CloudKit",
                en: "CloudKit Sync"
            ),
            description: Lang.pick(
                ar: "أصبحت مزامنة نتائج البحث المحفوظة والملاحظات أكثر ثباتاً بين الأجهزة.",
                id: "Sinkronisasi hasil pencarian tersimpan yang lebih stabil antar perangkat.",
                en: "Saved search results and annotations now sync more reliably across devices."
            )
        ),
    ]
    #endif
}

// MARK: - Views

struct WelcomeScreenView: View {
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text(verbatim: Lang.pick(
                    ar: "ما الجديد",
                    id: "Apa Yang Baru",
                    en: "What's New"
                ))
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                #if os(iOS)
                .padding(.top, 40)
                #else
                .padding(.top)
                #endif

                VStack(alignment: .leading, spacing: 24) {
                    ForEach(makeFeatures(), id: \.title) { item in
                        FeatureRow(
                            iconName: item.iconName,
                            iconColor: item.iconColor,
                            title: item.title,
                            description: item.description,
                            badge: item.badge
                        )
                    }
                }
                .padding(.horizontal)

                Button(action: onDismiss) {
                    Text(verbatim: Lang.pick(
                        ar: "متابعة",
                        id: "Lanjutkan",
                        en: "Continue"
                    ))
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .padding()
        }
    }
}

struct FeatureRow: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    var badge: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(iconColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(verbatim: title)
                        .font(.headline)

                    if let badge {
                        Text(verbatim: badge)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }

                Text(verbatim: description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WelcomeScreenView(onDismiss: {})
}
