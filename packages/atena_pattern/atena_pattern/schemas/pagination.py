from math import ceil

from fastapi import Query

MAX_PER_PAGE = 100


class PageParams:
    def __init__(
        self,
        page: int = Query(default=1, ge=1),
        per_page: int = Query(default=20, ge=1),
    ) -> None:
        self.page = page
        self.per_page = min(per_page, MAX_PER_PAGE)

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.per_page


def pagination_meta(page: int, per_page: int, total: int) -> dict[str, int]:
    return {
        "page": page,
        "per_page": per_page,
        "total": total,
        "total_pages": ceil(total / per_page) if total else 0,
    }
