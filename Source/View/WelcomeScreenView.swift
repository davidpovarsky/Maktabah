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
    [
        FeatureItem(
            iconName: "arrow.triangle.2.circlepath.icloud.fill",
            iconColor: .blue,
            title: Lang.pick(
                ar: "تحديث المزامنة",
                id: "Pembaruan Sinkronisasi",
                en: "Sync Update"
            ),
            description: Lang.pick(
                ar: "نظام مزامنة CloudKit جديد. يرجى تحديث التطبيق على جميع أجهزتك لتجنب تعارض البيانات.",
                id: "Sistem sinkronisasi CloudKit baru. Mohon perbarui aplikasi di semua perangkat Anda agar data tidak konflik.",
                en: "New CloudKit sync system. Please update the app on all your devices to avoid data conflicts."
            ),
            badge: Lang.pick(
                ar: "مهمة",
                id: "Penting",
                en: "Important"
            )
        ),
        FeatureItem(
            iconName: "square.and.arrow.down.on.square.fill",
            iconColor: .green,
            title: Lang.pick(
                ar: "الاستيراد والتنزيل الجماعي",
                id: "Impor Buku & Unduhan Serentak",
                en: "Import & Bulk Download"
            ),
            description: Lang.pick(
                ar: "نزّل كتباً كثيرة دفعةً واحدة واستورد الكتب دون الحاجة إلى اتصال بالإنترنت.",
                id: "Unduh banyak buku sekaligus dan impor buku secara offline dengan mudah.",
                en: "Download many books at once and import books offline without an internet connection."
            )
        ),
        FeatureItem(
            iconName: "text.bubble.fill",
            iconColor: .orange,
            title: Lang.pick(
                ar: "دعم متعدد اللغات",
                id: "Dukungan Multibahasa",
                en: "Multilingual Support"
            ),
            description: Lang.pick(
                ar: "تحسين كبير في عرض النصوص متعددة اللغات على شاشة القراءة.",
                id: "Rendering adaptif terhadap kitab multibahasa (RTL & LTR).",
                en: "Significantly improved multilingual book text rendering."
            )
        ),
        FeatureItem(
            iconName: "internaldrive.fill",
            iconColor: .purple,
            title: Lang.pick(
                ar: "أداء أقصى",
                id: "Performa Maksimal",
                en: "Maximum Performance"
            ),
            description: Lang.pick(
                ar: "محرك قاعدة بيانات محلي جديد لتصفح وبحث فوري.",
                id: "Mesin database native yang baru untuk kecepatan navigasi dan pencarian yang instan.",
                en: "New native database engine for instant navigation and search speed."
            )
        ),
    ]
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
                .controlSize(.large)
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
