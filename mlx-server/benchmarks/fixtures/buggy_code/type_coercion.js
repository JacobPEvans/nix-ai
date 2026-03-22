/**
 * User input validation utilities.
 */

function validateAge(input) {
  // BUG 1: Loose equality - "0" == false is true
  if (input == false) {
    return { valid: false, error: "Age is required" };
  }
  // BUG 2: Missing radix parameter
  const age = parseInt(input);
  if (isNaN(age) || age < 0 || age > 150) {
    return { valid: false, error: "Invalid age" };
  }
  return { valid: true, value: age };
}

function getDiscount(quantity) {
  // BUG 3: Falsy check fails for quantity 0
  if (!quantity) {
    return 0;
  }
  if (quantity >= 10) return 0.2;
  if (quantity >= 5) return 0.1;
  return 0;
}

function findUser(users, id) {
  // BUG 1 again: loose equality - number vs string comparison
  return users.find(u => u.id == id);
}

module.exports = { validateAge, getDiscount, findUser };
