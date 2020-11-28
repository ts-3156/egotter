class Order {
  constructor(id) {
    this.id = id;
  }

  cancel() {
    var url = '/api/v1/orders/cancel'; // api_v1_orders_cancel_path
    var id = this.id;

    $.post(url, {id: id}).done(function (res) {
      ToastMessage.info(res.message);
      setTimeout(function () {
        window.location.reload();
      }, 5000);
    }).fail(function (xhr, textStatus, errorThrown) {
      var message = extractErrorMessage(xhr, textStatus, errorThrown);
      ToastMessage.warn(message);
    });
  }
}

window.Order = Order;
