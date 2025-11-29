/**
 * Orgasmtoy.com Theme JavaScript
 * Custom enhancements for user experience
 */

define([
    'jquery',
    'jquery/ui'
], function($) {
    'use strict';

    return function(config, element) {

        /**
         * Discreet shipping badge display
         */
        function initDiscreetBadges() {
            var badges = '<div class="privacy-badges" style="margin: 20px 0; text-align: center;">' +
                '<span class="discreet-shipping-badge">Discreet Shipping</span>' +
                '<span class="privacy-badge">Secure Checkout</span>' +
                '<span class="privacy-badge">Privacy Guaranteed</span>' +
                '</div>';

            // Add to product pages
            if ($('.product-info-main').length) {
                $('.product-info-main .product-add-form').before(badges);
            }

            // Add to checkout
            if ($('.checkout-container').length) {
                $('.opc-wrapper').prepend(badges);
            }
        }

        /**
         * Enhanced product image zoom
         */
        function initImageZoom() {
            $('.product-image-photo').on('click', function() {
                $(this).toggleClass('zoomed');
            });
        }

        /**
         * Smooth scroll for anchor links
         */
        function initSmoothScroll() {
            $('a[href^="#"]').on('click', function(e) {
                var target = $(this.getAttribute('href'));
                if (target.length) {
                    e.preventDefault();
                    $('html, body').stop().animate({
                        scrollTop: target.offset().top - 100
                    }, 600);
                }
            });
        }

        /**
         * Add to cart button enhancement
         */
        function enhanceAddToCart() {
            $('#product-addtocart-button').on('click', function() {
                var $btn = $(this);
                $btn.addClass('loading');

                setTimeout(function() {
                    $btn.removeClass('loading');
                }, 2000);
            });
        }

        /**
         * Privacy mode toggle (optional - for screenshots, etc)
         */
        function initPrivacyMode() {
            // Add a subtle indicator that can be toggled
            var privacyToggle = '<button class="privacy-toggle" style="position: fixed; bottom: 20px; right: 20px; z-index: 1000; display: none;">' +
                '<span>👁️</span>' +
                '</button>';

            $('body').append(privacyToggle);

            $('.privacy-toggle').on('click', function() {
                $('body').toggleClass('privacy-mode');
            });
        }

        /**
         * Newsletter signup validation
         */
        function initNewsletterValidation() {
            $('.newsletter-subscribe').on('submit', function(e) {
                var email = $(this).find('input[type="email"]').val();
                if (!isValidEmail(email)) {
                    e.preventDefault();
                    alert('Please enter a valid email address');
                }
            });
        }

        /**
         * Email validation helper
         */
        function isValidEmail(email) {
            var re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            return re.test(email);
        }

        /**
         * Initialize all enhancements
         */
        $(document).ready(function() {
            initDiscreetBadges();
            initImageZoom();
            initSmoothScroll();
            enhanceAddToCart();
            initPrivacyMode();
            initNewsletterValidation();
        });
    };
});
