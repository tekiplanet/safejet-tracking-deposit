import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { EmailTemplatesService } from './email-templates.service';
import { LoginInfoDto } from '../auth/dto/login-info.dto';

@Injectable()
export class EmailService {
  private transporter;

  constructor(
    private readonly configService: ConfigService,
    private readonly emailTemplatesService: EmailTemplatesService,
  ) {
    // Log the SMTP config for debugging
    console.log('SMTP Config:', {
      host: this.configService.get<string>('SMTP_HOST'),
      port: this.configService.get<number>('SMTP_PORT'),
      user: this.configService.get<string>('SMTP_USER'),
    });

    this.transporter = nodemailer.createTransport({
      host: this.configService.get<string>('SMTP_HOST'),
      port: this.configService.get<number>('SMTP_PORT'),
      secure: false,
      auth: {
        user: this.configService.get<string>('SMTP_USER'),
        pass: this.configService.get<string>('SMTP_PASSWORD')
      },
      tls: {
        rejectUnauthorized: false
      }
    });

    // Verify connection
    this.transporter.verify((error, success) => {
      if (error) {
        console.error('SMTP connection error:', error);
      } else {
        console.log('SMTP server is ready');
      }
    });
  }

  async sendVerificationEmail(email: string, code: string) {
    try {
      await this.transporter.sendMail({
        from: '"SafeJet Exchange" <noreply@safejet.com>',
        to: email,
        subject: 'Verify Your Email - SafeJet Exchange',
        html: this.emailTemplatesService.verificationEmail(code),
      });
    } catch (error) {
      console.error('Email sending failed:', error);
    }
  }

  async sendWelcomeEmail(email: string, userName: string) {
    await this.transporter.sendMail({
      from: '"SafeJet Exchange" <noreply@safejet.com>',
      to: email,
      subject: 'Welcome to SafeJet Exchange - Start Your Trading Journey!',
      html: this.emailTemplatesService.welcomeEmail(userName),
    });
  }

  async sendPasswordResetEmail(email: string, code: string) {
    try {
      const info = await this.transporter.sendMail({
        from: `"SafeJet Exchange" <${this.configService.get('SMTP_USER')}>`,
        to: email,
        subject: 'Reset Your Password - SafeJet Exchange',
        html: this.emailTemplatesService.passwordResetEmail(code),
      });
      console.log('Message sent: %s', info.messageId);
    } catch (error) {
      console.error('Password reset email failed:', error);
      // Don't throw, just log the error
    }
  }

  async sendPasswordChangedEmail(email: string) {
    await this.transporter.sendMail({
      from: '"SafeJet Exchange" <noreply@safejet.com>',
      to: email,
      subject: 'Password Changed Successfully - SafeJet Exchange',
      html: this.emailTemplatesService.passwordChangedEmail(),
    });
  }

  async send2FAEnabledEmail(email: string) {
    await this.transporter.sendMail({
      from: '"SafeJet Exchange" <noreply@safejet.com>',
      to: email,
      subject: '2FA Enabled - SafeJet Exchange',
      html: this.emailTemplatesService.twoFactorEnabledEmail(),
    });
  }

  async send2FADisabledEmail(email: string) {
    await this.transporter.sendMail({
      from: '"SafeJet Exchange" <noreply@safejet.com>',
      to: email,
      subject: '2FA Disabled - SafeJet Exchange Security Alert',
      html: this.emailTemplatesService.twoFactorDisabledEmail(),
    });
  }

  async sendLoginNotificationEmail(email: string, loginInfo: LoginInfoDto) {
    await this.transporter.sendMail({
      from: '"SafeJet Exchange" <noreply@safejet.com>',
      to: email,
      subject: 'New Login Detected - SafeJet Exchange',
      html: this.emailTemplatesService.loginNotificationEmail(loginInfo),
    });
  }
} 