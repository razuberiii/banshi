class DeliveryJob < ApplicationJob
  queue_as :distribution
  def perform(delivery_id)
    delivery = Delivery.find_by(id: delivery_id)
    Distributor.deliver!(delivery: delivery) if delivery
  end
end
