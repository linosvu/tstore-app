/// Lý do thất bại khi phiếu đang «Không liên hệ được» (manager đóng phiếu).
const contactFailReasonCodes = <String>[
  'no_answer',
  'wrong_contact',
  'customer_refuse',
  'other',
];

const contactFailReasonLabels = <String, String>{
  'no_answer': 'Khách không nghe máy / bỏ ngang',
  'wrong_contact': 'SĐT/địa chỉ sai',
  'customer_refuse': 'Khách từ chối hỗ trợ',
  'other': 'Khác',
};

String contactFailReasonLabel(String code) =>
    contactFailReasonLabels[code] ?? code;
