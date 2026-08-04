import SwiftUI

enum DecantImage: String {
    case onboardingProfile = "onboarding-profile"
    case onboardingRack = "onboarding-rack"
    case onboardingBottle = "onboarding-bottle"
    case rackBanner = "rack-banner"
    case emptyCellar = "empty-cellar"
    case emptyTastings = "empty-tastings"
    case emptyLedger = "empty-ledger"
    case drinkNextBanner = "drink-next-banner"
    case maturityDial = "maturity-dial"
    case backupEmpty = "backup-empty"

    var image: Image { Image(rawValue) }
}
