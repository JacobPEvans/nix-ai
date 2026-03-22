"""Utilities with subtle off-by-one errors."""


def paginate(items, page, page_size=10):
    """Return a page of items (1-indexed pages)."""
    # BUG 1: Fence-post error - should be (page-1)*page_size
    start = page * page_size
    end = start + page_size
    return items[start:end]


def binary_search(sorted_list, target):
    """Find target in sorted list, return index or -1."""
    low, high = 0, len(sorted_list)  # BUG 2: should be len-1
    while low <= high:
        mid = (low + high) // 2
        if sorted_list[mid] == target:
            return mid
        elif sorted_list[mid] < target:
            low = mid + 1
        else:
            high = mid - 1
    return -1


def max_sum_subarray(arr, k):
    """Find maximum sum of subarray of size k."""
    if len(arr) < k:
        return 0
    window_sum = sum(arr[:k])
    max_sum = window_sum
    # BUG 3: range should go to len(arr), not len(arr)-1
    for i in range(k, len(arr) - 1):
        window_sum += arr[i] - arr[i - k]
        max_sum = max(max_sum, window_sum)
    return max_sum
