"""
Mind Parking Lot Page Object for FocusEcho
Full CRUD operations: Create thought, Read/Filter thoughts, Update status, Delete thoughts.
"""

from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import Select
from automation.pages.base_page import BasePage

class ParkingLotPage(BasePage):
    """Page object for Parking Lot CRUD module."""

    LOC_PARKING_ITEM_INPUT = (By.ID, "parking-item-input")
    LOC_PARKING_PRIORITY_SELECT = (By.ID, "parking-priority-select")
    LOC_PARKING_SUBMIT_BTN = (By.ID, "parking-submit-btn")
    LOC_PARKING_ITEM_ERROR = (By.ID, "parking-item-error")

    LOC_PARKING_ITEMS_LIST = (By.ID, "parking-items-list")
    LOC_PARKING_COUNT_BADGE = (By.ID, "parking-count-badge")
    LOC_PARKING_ACTIVE_COUNT = (By.ID, "parking-active-count")
    LOC_CLEAR_COMPLETED_BTN = (By.ID, "clear-completed-parking-btn")

    LOC_PARKING_SEARCH_INPUT = (By.ID, "parking-search-input")
    LOC_FILTER_ALL = (By.ID, "filter-all")
    LOC_FILTER_ACTIVE = (By.ID, "filter-active")
    LOC_FILTER_COMPLETED = (By.ID, "filter-completed")

    def add_thought(self, text: str, priority: str = "Medium") -> None:
        """Create a new parking lot thought."""
        self.type_text(self.LOC_PARKING_ITEM_INPUT, text)
        select_elem = self.find_element(self.LOC_PARKING_PRIORITY_SELECT)
        Select(select_elem).select_by_visible_text(priority)
        self.click(self.LOC_PARKING_SUBMIT_BTN)

    def get_items_count(self) -> int:
        """Return the count of rendered items."""
        items = self.driver.find_elements(By.CSS_SELECTOR, "#parking-items-list .parking-item")
        return len(items)

    def search_thoughts(self, query: str) -> None:
        """Search/filter parking thoughts."""
        self.type_text(self.LOC_PARKING_SEARCH_INPUT, query)

    def filter_by(self, filter_name: str) -> None:
        """Filter by 'all', 'active', or 'completed'."""
        f_map = {
            "all": self.LOC_FILTER_ALL,
            "active": self.LOC_FILTER_ACTIVE,
            "completed": self.LOC_FILTER_COMPLETED
        }
        if filter_name.lower() in f_map:
            self.click(f_map[filter_name.lower()])

    def toggle_first_item_complete(self) -> None:
        """Toggle checkbox of the first item in the list."""
        checkbox = self.find_element((By.CSS_SELECTOR, "#parking-items-list .parking-item input[type='checkbox']"))
        checkbox.click()

    def delete_first_item(self) -> None:
        """Delete the first item in the list."""
        del_btn = self.find_element((By.CSS_SELECTOR, "#parking-items-list .delete-parking-btn"))
        del_btn.click()

    def clear_completed(self) -> None:
        """Click clear completed button."""
        self.click(self.LOC_CLEAR_COMPLETED_BTN)

    def get_active_count_text(self) -> str:
        """Get active count badge text."""
        return self.find_element(self.LOC_PARKING_ACTIVE_COUNT).text
