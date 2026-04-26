document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('loginForm');

    if (loginForm) {
        loginForm.addEventListener('submit', function(e) {
            e.preventDefault();

            // Input values gannawa
            const email = document.getElementById('email').value.trim();
            const password = document.getElementById('password').value.trim();

            // Mehema dummy validation ekak demmu (Backend eka hadanakal)
            // Oyaage email eka: admin@saferide.lk | Password: admin123
            if (email === "admin@saferide.lk" && password === "admin123") {
                
                // Login success kiyala pennanna podi alert ekak
                console.log("Login Successful!");
                
                // Dashboard ekata redirect karanawa
                window.location.href = "index.html"; 
            } else {
                // Email eka hari password eka hari waradi nam
                alert("Invalid Email or Password. Please try again!");
            }
        });
    }
});