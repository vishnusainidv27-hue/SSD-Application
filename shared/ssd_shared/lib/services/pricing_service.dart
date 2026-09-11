/// Date-effective pricing & billing calculation logic.
/// Runs on-device inside the Admin app (no Cloud Functions – see Requirements §2.4).
/// Built in Phase 3 (price lookup) and Phase 7 (full bill generation).
class PricingService {
  // TODO (Phase 3): rateEffectiveOn(milkType, date) -> looks up priceList.
  // TODO (Phase 7): generateBill(customerId, periodFrom, periodTo) -> BillModel
  //                 by summing each delivered day at the rate effective that day.
}
