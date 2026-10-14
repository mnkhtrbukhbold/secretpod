/// Shared page sizes for list requests, controls, and session resets.
class PaginationSettings {
  static const defaultPageSize = 10;
  static const pageSizes = [10, 25, 50, 100];
  static const primaryLists = ['secrets', 'activity', 'members'];
  static const lists = [
    ...primaryLists,
    'received-invitations',
    'sent-invitations',
  ];
}
